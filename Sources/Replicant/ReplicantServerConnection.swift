//
//  ReplicantServerConnection.swift
//  Replicant
//
//  Created by Adelita Schule on 12/3/18.
//

import Foundation
import Network
import CryptoKit
import SwiftQueue
import Transport
import ReplicantSwift

open class ReplicantServerConnection: Connection
{
    // FIXME: Constants called out twice, should be global
    public let aesOverheadSize = 113
    public let payloadLengthOverhead = 2
    
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var replicantConfig: ReplicantServerConfig
    public var replicantServerModel: ReplicantServerModel
    
    let unencryptedChunkSize: UInt16
    
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
                 logQueue: Queue<String>)
    {
        guard let newReplicant = ReplicantServerModel(withConfig: replicantConfig, logQueue: logQueue)
        else
        {
            print("\nFailed to initialize ReplicantConnection because we failed to initialize Replicant.\n")
            return nil
        }
        
        self.logQueue = logQueue
        self.network = connection
        self.replicantConfig = replicantConfig
        self.replicantServerModel = newReplicant
        self.unencryptedChunkSize = replicantServerModel.config.chunkSize - UInt16(aesOverheadSize + payloadLengthOverhead)
        
        introductions
        {
            (maybeIntroError) in
            
            guard maybeIntroError == nil
                else
            {
                print("\nError attempting to meet the server during Replicant Connection Init: \(maybeIntroError!)\n")
                return
            }
            
            print("\n New Replicant connection is ready. 🎉 \n")
        }
    }
    
    public func start(queue: DispatchQueue)
    {
        network.stateUpdateHandler = self.stateUpdateHandler
        network.start(queue: queue)
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
        
        sendBufferChunks(contentContext: contentContext, isComplete: isComplete, completion: completion)
    }
    
    func sendBufferChunks(contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        // Only encrypt and send over network when chunk size is available, leftovers to the buffer
        guard self.sendBuffer.count >= (unencryptedChunkSize) else
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
        
        guard let clientPublicKey = self.replicantServerModel.polish.clientPublicKey else
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
        
        let payloadData = self.sendBuffer[0 ..< unencryptedChunkSize]
        let payloadSize = UInt16(unencryptedChunkSize)
        let dataChunk = payloadSize.data + payloadData
        let maybeEncryptedData = self.replicantServerModel.polish.controller.encrypt(payload: dataChunk, usingReceiverPublicKey: clientPublicKey, senderPrivateKey: replicantServerModel.polish.privateKey)
        
        // Buffer should only contain unsent data
        self.sendBuffer = self.sendBuffer[unencryptedChunkSize...]
        
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
            
            if self.sendBuffer.count >= (self.unencryptedChunkSize)
            {
                // Play it again Sam
                self.sendBufferChunks(contentContext: contentContext, isComplete: isComplete, completion: completion)
            }
            else
            {
                // Start the timer
                if self.sendBuffer.count > 0
                {
                    self.sendTimer = Timer(timeInterval: TimeInterval(self.replicantConfig.chunkTimeout), target: self, selector: #selector(self.chunkTimeout), userInfo: nil, repeats: true)
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
        self.receive(minimumIncompleteLength: 1, maximumLength: 1000000, completion: completion)
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
            network.receive(minimumIncompleteLength: Int(replicantServerModel.config.chunkSize), maximumLength: Int(replicantServerModel.config.chunkSize))
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
                
                let maybeReturnData = self.handleReceivedData(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, encryptedData: someData)
                
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
    func handleReceivedData(minimumIncompleteLength: Int, maximumLength: Int, encryptedData: Data) -> Data?
    {
        // Try to decrypt the entire contents of the encrypted buffer
        guard let clientPublicKey = self.replicantServerModel.polish.clientPublicKey
        else
        {
            print("Unable to decrypt received data. We do not have the client's public key.")
            return nil
        }
        
        do
        {
            let data = try ChaChaPoly.SealedBox(combined: encryptedData)
            guard let decryptedData = self.replicantServerModel.polish.controller.decrypt(payload: data, usingReceiverPrivateKey: self.replicantServerModel.polish.privateKey, senderPublicKey: clientPublicKey)
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
        catch let sealedBoxError
        {
            print("Failed to convert received data to sealed box: \(sealedBoxError.localizedDescription)")
            return nil
        }
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
        
    func handshake(completion: @escaping (Error?) -> Void)
    {
        print("\n🤝  Replicant Server handshake called.")
        let replicantChunkSize = self.replicantServerModel.config.chunkSize
        let keySize = 64
        let keyDataSize = keySize + 1
        
        //Call receive first
        self.network.receive(minimumIncompleteLength: Int(replicantChunkSize), maximumLength: Int(replicantChunkSize))
        {
            (maybeResponse1Data, maybeResponse1Context, _, maybeResponse1Error) in
            
            print("\n🤝  network.receive callback from handshake.")
            print("\n🤝  Data received: \(String(describing: maybeResponse1Data?.bytes))")
            
            // Parse received public key and store it
            guard maybeResponse1Error == nil
            else
            {
                print("\n\n🤝  Received an error while waiting for response from server acfter sending key: \(maybeResponse1Error!)\n")
                completion(maybeResponse1Error!)
                return
            }
            
            // Make sure we have data
            guard let clientEncryptedData = maybeResponse1Data
            else
            {
                print("\nClient introduction did not contain data.\n")
                completion(HandshakeError.noClientKeyData)
                return
            }
            
            guard let clientPublicKey = self.replicantServerModel.polish.clientPublicKey
                else
            {
                print("Unable to complete handshake. We do not have the client's public key.")
                completion(HandshakeError.missingClientKey)
                return
            }
            
            // Decrypt the received data
            do
            {
                let sealedBox = try ChaChaPoly.SealedBox(combined: clientEncryptedData)
            guard let clientPaddedKey = self.replicantServerModel.polish.controller.decrypt(
                payload: sealedBox,
                usingReceiverPrivateKey: self.replicantServerModel.polish.privateKey,
                senderPublicKey: clientPublicKey)
                else
                {
                    print("\nCould not decrypt client introduction.\n")
                    completion(HandshakeError.unableToDecryptData)
                    return
                }
                
                // Make sure the decrypted data is at least the size of a key
                guard clientPaddedKey.count >= keyDataSize
                else
                {
                    print("\nReceived a client key that is \(clientPaddedKey.count), but it should have been \(keyDataSize)\n")
                    completion(HandshakeError.clientKeyDataIncorrectSize)
                    return
                }
                
                // Key data is the first chunk of keyDataSize
                let clientKeyData = clientPaddedKey[0 ..< keyDataSize]
                
                // Convert data to SecKey
                //FIXME: Will decode key method account for leading 04?
                guard let clientKey = self.replicantServerModel.polish.controller.decodeKey(fromData: clientKeyData)
                else
                {
                    print("\nUnable to decode client key.\n")
                    completion(HandshakeError.invalidClientKeyData)
                    return
                }
                
                self.replicantServerModel.polish.clientPublicKey = clientKey
                
                let configChunkSize = Int(self.replicantServerModel.config.chunkSize)
                
                //Generate random data of chunk size
                var randomData = Data(count: configChunkSize)
                let result = randomData.withUnsafeMutableBytes{
                    SecRandomCopyBytes(kSecRandomDefault, configChunkSize, $0)
                }
                
                guard result == errSecSuccess
                else
                {
                    print("\nUnable to create random bytes for response to client key.\n")
                    completion(HandshakeError.dataCreationError)
                    return
                }
                
                //Send random data to client
                self.network.send(content: randomData, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
                {
                    (maybeError) in
                    
                    guard maybeError == nil
                        else
                    {
                        print("\nReceived error from client when sending random data in handshake: \(maybeError!)")
                        completion(maybeError!)
                        return
                    }
                }))
                
            }
            catch let sealedBoxError
            {
                print("Error creating sealed box from received data: \(sealedBoxError)")
                completion(sealedBoxError)
                return
            }
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
            
            self.handshake(completion:
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
            })
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
        
        guard payloadSize > 0, payloadSize < replicantServerModel.config.chunkSize else
        {
            bufferLock.leave()
            return
        }
        
        guard let clientPublicKey = self.replicantServerModel.polish.clientPublicKey else
        {
            print("Received a send command when we do not yet have the client's public key.")
            bufferLock.leave()
            return
        }
        
        let payloadData = self.sendBuffer
        let paddingSize = Int(unencryptedChunkSize) - payloadSize
        let padding = Data(repeating: 0, count: paddingSize)
        let dataChunk = UInt16(payloadSize).data + payloadData + padding
        let maybeEncryptedData = self.replicantServerModel.polish.controller.encrypt(payload: dataChunk, usingReceiverPublicKey: clientPublicKey, senderPrivateKey: self.replicantServerModel.polish.privateKey)
        
        // Buffer should only contain unsent data
        self.sendBuffer = Data()
        
        // Keep calling network.send if the leftover data is at least chunk size
        self.network.send(content: maybeEncryptedData?.ciphertext, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
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
