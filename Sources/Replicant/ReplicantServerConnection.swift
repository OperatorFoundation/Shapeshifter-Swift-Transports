//
//  ReplicantServerConnection.swift
//  Replicant
//
//  Created by Adelita Schule on 12/3/18.
//

import Foundation
import Dispatch
import Network
import CryptoKit
import Flower
import SwiftQueue
import Transport
import ReplicantSwift

open class ReplicantServerConnection: Connection
{
    // FIXME: Constants called out twice, should be global
    
    // FIXME: No longer using AES Overhead?
    //public let aesOverheadSize = 113
    public let payloadLengthOverhead = 2
    
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var replicantConfig: ReplicantServerConfig
    public var replicantServerModel: ReplicantServerModel
    
    // FIXME: Unencrypted chunk size for non-polish instances
    var unencryptedChunkSize: UInt16 = 400
    
    var logQueue: Queue<String>
    var sendTimer: Timer?
    var bufferLock = DispatchGroup()
    var networkQueue = DispatchQueue(label: "Replicant Queue")
    var sendBufferQueue = DispatchQueue(label: "SendBuffer Queue")
    var network: Connection
    var sendBuffer = Data()
    var decryptedReceiveBuffer = Data()
    
    public init?(connection: Connection,
                 parameters: NWParameters,
                 replicantConfig: ReplicantServerConfig,
                 logQueue: Queue<String>,
                 completion: @escaping (Error?) -> Void)
    {
        guard let newReplicant = ReplicantServerModel(withConfig: replicantConfig, logQueue: logQueue)
        else
        {
            print("\nFailed to initialize ReplicantConnection because we failed to initialize Replicant.\n")
            completion(ReplicantError.initializationError)
            return nil
        }
        
        self.logQueue = logQueue
        self.network = connection
        self.replicantConfig = replicantConfig
        self.replicantServerModel = newReplicant
        if let polish = replicantServerModel.polish
        {
            self.unencryptedChunkSize =
            polish.chunkSize - UInt16(payloadLengthOverhead)
        }
        
        introductions
        {
            (maybeIntroError) in
            
            guard maybeIntroError == nil
                else
            {
                print("\nError attempting to meet the server during Replicant Connection Init: \(maybeIntroError!)\n")
                completion(maybeIntroError!)
                return
            }
            
            print("\n New Replicant connection is ready. 🎉 \n")
            
            // Data Handling
            
            self.networkQueue.async
            {
                self.startReceivingPackets()
            }
            
            self.sendBufferQueue.async
            {
                self.startSendingPackets()
            }
            
            completion(nil)
        }
    }
    
    public func start(queue: DispatchQueue)
    {
        network.stateUpdateHandler = self.stateUpdateHandler
        network.start(queue: queue)
    }
    
    func startReceivingPackets()
    {
        // This is actually kicking off a loop that will continue reading
        self.readMessages
        {
            (message) in
            
            self.logQueue.enqueue("Received a message: \(message)")
        }
    }
    
    func startSendingPackets()
    {
        
    }
    
    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        // Lock so that the timer cannot fire and change the buffer.
        bufferLock.enter()
        
        guard let someData = content else
        {
            print("Received a send command with no content.")
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
                bufferLock.leave()
                return
            default:
                bufferLock.leave()
                return
            }
        }
        
        self.sendBuffer.append(someData)
        
        if let polish = replicantConfig.polish as? SilverServerConfig
        {
            sendPolishedBufferChunks(polishConfig: polish, contentContext: contentContext, isComplete: isComplete, completion: completion)
        }
        else
        {
            sendBufferChunks(contentContext: contentContext, isComplete: isComplete, completion: completion)
        }
        
    }
    
    func sendPolishedBufferChunks(polishConfig: SilverServerConfig, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        // Only encrypt and send over network when chunk size is available, leftovers to the buffer
        guard self.sendBuffer.count >= (polishConfig.chunkSize)
            else
        {
            print("Received a send command with content less than chunk size.")
            switch completion
            {
                case .contentProcessed(let handler):
                    handler(nil)
                    bufferLock.leave()
                    return
                default:
                    bufferLock.leave()
                    return
            }
        }
        
        guard let silverServer = self.replicantServerModel.polish, let clientPublicKey = silverServer.clientPublicKey else
        {
            print("Received a send command when we do not yet have the client's public key.")
            switch completion
            {
                case .contentProcessed(let handler):
                    handler(NWError.posix(POSIXErrorCode.ENOATTR))
                    bufferLock.leave()
                    return
                default:
                    bufferLock.leave()
                    return
            }
        }
        
        let payloadData = self.sendBuffer[0 ..< polishConfig.chunkSize]
        let payloadSize = polishConfig.chunkSize
        let dataChunk = payloadSize.data + payloadData
        guard let symmetricKey = silverServer.controller.deriveSymmetricKey(receiverPublicKey: clientPublicKey, senderPrivateKey: silverServer.privateKey)
        else
        {
            print("Received a send command but we could not derive the symmetric key.")
            switch completion
            {
                case .contentProcessed(let handler):
                    handler(NWError.posix(POSIXErrorCode.ENOATTR))
                    bufferLock.leave()
                    return
                default:
                    bufferLock.leave()
                    return
            }
        }
        
        let maybeEncryptedData = silverServer.controller.encrypt(payload: dataChunk, symmetricKey: symmetricKey)
        
        // Buffer should only contain unsent data
        self.sendBuffer = self.sendBuffer[polishConfig.chunkSize...]
        
        // Turn off the timer
        if sendTimer != nil
        {
            self.sendTimer!.invalidate()
            self.sendTimer = nil
        }
        
        // Keep calling network.send if the leftover data is at least chunk size
        self.network.send(content: maybeEncryptedData?.ciphertext, contentContext: contentContext, isComplete: isComplete, completion: NWConnection.SendCompletion.contentProcessed(
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("Received an error on Send:\(error)")
                self.sendTimer!.invalidate()
                self.sendTimer = nil
                
                switch completion
                {
                    case .contentProcessed(let handler):
                        handler(error)
                        self.bufferLock.leave()
                        return
                    default:
                        self.bufferLock.leave()
                        return
                }
            }
            
            if self.sendBuffer.count >= (polishConfig.chunkSize)
            {
                // Play it again Sam
                self.sendPolishedBufferChunks(polishConfig: polishConfig, contentContext: contentContext, isComplete: isComplete, completion: completion)
            }
            else
            {
                // Start the timer
                if self.sendBuffer.count > 0
                {
                    
                    self.sendTimer = Timer(timeInterval: TimeInterval(polishConfig.chunkTimeout),
                                           target: self,
                                           selector: #selector(self.chunkTimeout),
                                           userInfo: nil,
                                           repeats: true)
                }
                
                switch completion
                {
                    // FIXME: There might be data in the buffer
                    case .contentProcessed(let handler):
                        handler(nil)
                        self.bufferLock.leave()
                        return
                    default:
                        self.bufferLock.leave()
                        return
                }
            }
        }))
    }
    
    func sendBufferChunks(contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        // FIXME: Chunk size is meant for configs that have polish, we need to decide how we want to handle no-polish replicants
        // Only encrypt and send over network when chunk size is available, leftovers to the buffer
        let unencryptedChunkSize: UInt16 = 400

        guard self.sendBuffer.count >= (unencryptedChunkSize)
            else
        {
            print("Received a send command with content less than chunk size.")
            switch completion
            {
                case .contentProcessed(let handler):
                    handler(nil)
                    bufferLock.leave()
                    return
                default:
                    bufferLock.leave()
                    return
            }
        }
        
        let payloadData = self.sendBuffer[0 ..< unencryptedChunkSize]
        let payloadSize = UInt16(unencryptedChunkSize)
        let dataChunk = payloadSize.data + payloadData
        
        // Buffer should only contain unsent data
        self.sendBuffer = self.sendBuffer[unencryptedChunkSize...]
        
        // Turn off the timer
        if sendTimer != nil
        {
            self.sendTimer!.invalidate()
            self.sendTimer = nil
        }
        
        // Keep calling network.send if the leftover data is at least chunk size
        self.network.send(content: dataChunk, contentContext: contentContext, isComplete: isComplete, completion: NWConnection.SendCompletion.contentProcessed(
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("Received an error on Send:\(error)")
                self.sendTimer!.invalidate()
                self.sendTimer = nil
                
                switch completion
                {
                    case .contentProcessed(let handler):
                        handler(error)
                        self.bufferLock.leave()
                        return
                    default:
                        self.bufferLock.leave()
                        return
                }
            }
            
            if self.sendBuffer.count >= (unencryptedChunkSize)
            {
                // Play it again Sam
                self.sendBufferChunks(contentContext: contentContext, isComplete: isComplete, completion: completion)
            }
            else
            {
                // Start the timer
                if self.sendBuffer.count > 0
                {
                    // FIXME: chunkTimeout is a Polish property, here we are sending with no polish
                    let timeout = 20
                    self.sendTimer = Timer(timeInterval: TimeInterval(timeout),
                                           target: self,
                                           selector: #selector(self.chunkTimeout),
                                           userInfo: nil,
                                           repeats: true)
                }
                
                switch completion
                {
                    // FIXME: There might be data in the buffer
                    case .contentProcessed(let handler):
                        handler(nil)
                        self.bufferLock.leave()
                        return
                    default:
                        self.bufferLock.leave()
                        return
                }
            }
        }))
    }
    
    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        if let polishServer = replicantServerModel.polish
        {
            receive(polish: polishServer, minimumIncompleteLength: 1, maximumLength: 1000000, completion: completion)
        }
        else
        {
            self.receive(minimumIncompleteLength: 1, maximumLength: 1000000, completion: completion)
        }
    }
    
    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        bufferLock.enter()
        
        // Check to see if we have min length data in decrypted buffer before calling network receive. Skip the call if we do.
        if decryptedReceiveBuffer.count >= minimumIncompleteLength
        {
            // Make sure that the slice we get isn't bigger than the available data count or the maximum requested.
            let sliceLength = decryptedReceiveBuffer.count < maximumLength ? decryptedReceiveBuffer.count : maximumLength
            
            // Return the requested amount
            let returnData = self.decryptedReceiveBuffer[0 ..< sliceLength]
            
            // Remove what was delivered from the buffer
            self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[sliceLength...]
            
            completion(returnData, NWConnection.ContentContext.defaultMessage, false, nil)
            bufferLock.leave()
            return
        }
        else
        {
            network.receive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength)
            {
                (maybeData, maybeContext, connectionComplete, maybeError) in
                
                // Check to see if we got data
                guard let someData = maybeData
                    else
                {
                    print("\nReceive called with no content.\n")
                    completion(maybeData, maybeContext, connectionComplete, maybeError)
                    return
                }
                
                let maybeReturnData = self.handleReceivedData(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, receivedData: someData)
                completion(maybeReturnData, maybeContext, connectionComplete, maybeError)
                self.bufferLock.leave()
                return
            }
        }
    }
    
    public func receive(polish: SilverServer, minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        bufferLock.enter()
        
        // Check to see if we have min length data in decrypted buffer before calling network receive. Skip the call if we do.
        if decryptedReceiveBuffer.count >= minimumIncompleteLength
        {
            // Make sure that the slice we get isn't bigger than the available data count or the maximum requested.
            let sliceLength = decryptedReceiveBuffer.count < maximumLength ? decryptedReceiveBuffer.count : maximumLength
            
            // Return the requested amount
            let returnData = self.decryptedReceiveBuffer[0 ..< sliceLength]
            
            // Remove what was delivered from the buffer
            self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[sliceLength...]
            
            completion(returnData, NWConnection.ContentContext.defaultMessage, false, nil)
            bufferLock.leave()
            return
        }
        else
        {
            network.receive(minimumIncompleteLength: Int(polish.chunkSize), maximumLength: Int(polish.chunkSize))
            {
                (maybeData, maybeContext, connectionComplete, maybeError) in
                
                // Check to see if we got data
                guard let someData = maybeData
                    else
                {
                    print("\nReceive called with no content.\n")
                    completion(maybeData, maybeContext, connectionComplete, maybeError)
                    return
                }
                
                let maybeReturnData = self.handleReceivedData(polish: polish, minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, encryptedData: someData)
                
                completion(maybeReturnData, maybeContext, connectionComplete, maybeError)
                self.bufferLock.leave()
                return
            }
        }
    }
    
    public func cancel()
    {
        network.cancel()
        
        if let stateUpdate = self.stateUpdateHandler
        {
            stateUpdate(NWConnection.State.cancelled)
        }
        
        if let viabilityUpdate = self.viabilityUpdateHandler
        {
            viabilityUpdate(false)
        }
    }
    /// This takes an optional data and adds it to the buffer before acting on min/max lengths
    func handleReceivedData(polish: SilverServer, minimumIncompleteLength: Int, maximumLength: Int, encryptedData: Data) -> Data?
    {
        // Try to decrypt the entire contents of the encrypted buffer
        guard let silverServerConnection = polish.newConnection(connection: network)
        else
        {
            print("Unable to decrypt received data: Failed to create a Silver connection")
             return nil
        }
        
        guard let decryptedData = silverServerConnection.unpolish(polishedData: encryptedData)
            else
        {
            print("Unable to decrypt encrypted receive buffer")
            return nil
        }
        
        // Add decrypted data to the decrypted buffer
        self.decryptedReceiveBuffer.append(decryptedData)
        
        // Check to see if the decrypted buffer meets min/max parameters
        guard decryptedReceiveBuffer.count >= minimumIncompleteLength
            else
        {
            // Not enough data return nothing
            return nil
        }
        
        // Make sure that the slice we get isn't bigger than the available data count or the maximum requested.
        let sliceLength = decryptedReceiveBuffer.count < maximumLength ? decryptedReceiveBuffer.count : maximumLength
        
        // Return the requested amount
        let returnData = self.decryptedReceiveBuffer[0 ..< sliceLength]
        
        // Remove what was delivered from the buffer
        self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[sliceLength...]
        
        return returnData
    }
    
    /// This takes an optional data and adds it to the buffer before acting on min/max lengths
    func handleReceivedData(minimumIncompleteLength: Int, maximumLength: Int, receivedData: Data) -> Data?
    {
        // ReceivedData was not encrypted to begin with
        // Add data to the decrypted buffer
        self.decryptedReceiveBuffer.append(receivedData)
        
        // Check to see if the decrypted buffer meets min/max parameters
        guard decryptedReceiveBuffer.count >= minimumIncompleteLength
            else
        {
            // Not enough data return nothing
            return nil
        }
        
        // Make sure that the slice we get isn't bigger than the available data count or the maximum requested.
        let sliceLength = decryptedReceiveBuffer.count < maximumLength ? decryptedReceiveBuffer.count : maximumLength
        
        // Return the requested amount
        let returnData = self.decryptedReceiveBuffer[0 ..< sliceLength]
        
        // Remove what was delivered from the buffer
        self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[sliceLength...]
        
        return returnData
    }
    
    func voightKampffTest(completion: @escaping (Error?) -> Void)
    {
        // Tone Burst
        if var toneBurst = self.replicantServerModel.toneBurst
        {
            toneBurst.play(connection: self.network)
            {
                maybeError in
                
                guard maybeError == nil else
                {
                    print("ToneBurst failed: \(maybeError!)")
                    completion(nil)
                    return
                }
                
                completion(maybeError)
            }
        }
        else
        {
            completion(nil)
        }
    }
    
    func introductions(completion: @escaping (Error?) -> Void)
    {
        voightKampffTest
        {
            (maybeVKError) in
            
            guard maybeVKError == nil
                else
            {
                self.stateUpdateHandler?(NWConnection.State.cancelled)
                completion(maybeVKError)
                return
            }
            
            if let polishServer = self.replicantServerModel.polish
            {
                guard var polishConnection = polishServer.newConnection(connection: self.network)
                    else
                {
                    completion(ReplicantError.invalidServerHandshake)
                    return
                }
                
                polishConnection.handshake(connection: self.network)
                {
                    (maybeHandshakeError) in
                    
                    if let handshakeError = maybeHandshakeError
                    {
                        self.stateUpdateHandler?(NWConnection.State.cancelled)
                        completion(handshakeError)
                        return
                    }
                    else
                    {
                        self.stateUpdateHandler?(NWConnection.State.ready)
                        completion(nil)
                    }
                }
            }
            else
            {
                completion(nil)
            }
        }
    }
    
    @objc func chunkTimeout()
    {
        // Lock so that send isn't called while we're working
        bufferLock.enter()

        self.sendTimer = nil
        
        // Double check the buffer to be sure that there is still data in there.
        print("\n⏰  Chunk Timeout Reached\n  ⏰")
        
        let payloadSize = sendBuffer.count

        if let polish = replicantServerModel.polish
        {
            guard let polishConnection = polish.newConnection(connection: network)
            else
            {
                print("Attempted to polish but failed to create a SilverServer PolishConnection")
                bufferLock.leave()
                return
            }
            
            guard payloadSize > 0, payloadSize < polish.chunkSize else
            {
                bufferLock.leave()
                return
            }
                
            let payloadData = self.sendBuffer
            let paddingSize = Int(unencryptedChunkSize) - payloadSize
            let padding = Data(repeating: 0, count: paddingSize)
            let dataChunk = UInt16(payloadSize).data + payloadData + padding
            let maybeEncryptedData = polishConnection.polish(inputData: dataChunk)
            
            // Buffer should only contain unsent data
            self.sendBuffer = Data()
            
            // Keep calling network.send if the leftover data is at least chunk size
            self.network.send(content: maybeEncryptedData, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
            {
                (maybeError) in
                
                if let error = maybeError
                {
                    print("Received an error on Send:\(error)")
                    
                    self.bufferLock.leave()
                    return
                }
                else
                {
                    self.bufferLock.leave()
                    return
                }
            }))
        }
        else /// Replicant without polish
        {
            guard payloadSize > 0
                else
            {
                bufferLock.leave()
                return
            }
                
            // FIXME: padding and unencrypted chunk size for non-polish
            let payloadData = self.sendBuffer
            let paddingSize = Int(unencryptedChunkSize) - payloadSize
            let padding = Data(repeating: 0, count: paddingSize)
            let dataChunk = UInt16(payloadSize).data + payloadData + padding
            
            // Buffer should only contain unsent data
            self.sendBuffer = Data()
            
            // Keep calling network.send if the leftover data is at least chunk size
            self.network.send(content: dataChunk, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
            {
                (maybeError) in
                
                if let error = maybeError
                {
                    print("Received an error on Send:\(error)")
                    
                    self.bufferLock.leave()
                    return
                }
                else
                {
                    self.bufferLock.leave()
                    return
                }
            }))
        }
    }
    
}
