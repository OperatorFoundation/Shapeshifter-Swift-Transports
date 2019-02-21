//
//  ReplicantConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Adelita Schule on 11/21/18.
//

import Foundation
import Network

import Transport
import ReplicantSwift

open class ReplicantConnection: Connection
{
    public let aesOverheadSize = 81
    public let payloadLengthOverhead = 2
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var config: ReplicantConfig
    public var replicantClientModel: ReplicantClientModel
    let unencryptedChunkSize: UInt16
    var sendTimer: Timer?
    
    var networkQueue = DispatchQueue(label: "Replicant Queue")
    var sendBufferQueue = DispatchQueue(label: "SendBuffer Queue")
    var bufferLock = DispatchGroup()
    var network: Connection
    var decryptedReceiveBuffer: Data
    var sendBuffer: Data
    
    public convenience init?(host: NWEndpoint.Host,
                 port: NWEndpoint.Port,
                 using parameters: NWParameters,
                 and config: ReplicantConfig)
    {
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        guard let newConnection = connectionFactory.connect(using: parameters)
            else
        {
            return nil
        }
        
        self.init(connection: newConnection, using: parameters, and: config)
    }
    
    public init?(connection: Connection,
                using parameters: NWParameters,
                and config: ReplicantConfig)
    {
        ///FIXME: This check is failing though parameters are tcp, indefinite
//        guard let prot = parameters.defaultProtocolStack.internetProtocol, let _ = prot as? NWProtocolTCP.Options
//            else
//        {
//            print("Attempted to initialize Replicant not as a TCP connection. Parameters: \(parameters.debugDescription)")
//            return nil
//        }

        guard let newReplicant = ReplicantClientModel(withConfig: config)
        else
        {
            print("\nFailed to initialize ReplicantConnection because we failed to initialize Replicant.\n")
            return nil
        }
        
        self.network = connection
        self.config = config
        self.replicantClientModel = newReplicant
        self.decryptedReceiveBuffer = Data()
        self.sendBuffer = Data()
        self.unencryptedChunkSize = replicantClientModel.config.chunkSize - UInt16(aesOverheadSize + payloadLengthOverhead)
        
        introductions
        {
            (maybeIntroError) in
            
            guard maybeIntroError == nil
                else
            {
                print("\nError attempting to meet the server during Replicant Connection Init.\n")
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
        // Lock so that the timer cannot fire and change the buffer. Unlock in the network send() callback.
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
        let maybeEncryptedData = self.replicantClientModel.polish.controller.encrypt(payload: dataChunk, usingPublicKey: self.replicantClientModel.polish.serverPublicKey)
        
        // Buffer should only contain unsent data
        self.sendBuffer = self.sendBuffer[unencryptedChunkSize...]
        
        // Turn off the timer
        if self.sendTimer != nil
        {
            self.sendTimer!.invalidate()
            self.sendTimer = nil
        }
        
        // Keep calling network.send if the leftover data is at least chunk size
        self.network.send(content: maybeEncryptedData, contentContext: contentContext, isComplete: isComplete, completion: NWConnection.SendCompletion.contentProcessed(
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("Received an error on Send:\(error)")
                if self.sendTimer != nil
                {
                    self.sendTimer!.invalidate()
                    self.sendTimer = nil
                }
                
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
                    self.sendTimer = Timer(timeInterval: TimeInterval(self.config.chunkTimeout), target: self, selector: #selector(self.chunkTimeout), userInfo: nil, repeats: true)
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
            network.receive(minimumIncompleteLength: Int(replicantClientModel.config.chunkSize), maximumLength: Int(replicantClientModel.config.chunkSize))
            {
                (maybeData, maybeContext, connectionComplete, maybeError) in
                
                // Check to see if we got data
                guard let someData = maybeData, someData.count == self.replicantClientModel.config.chunkSize
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
        guard let decryptedData = self.replicantClientModel.polish.controller.decrypt(payload: encryptedData, usingPrivateKey: self.replicantClientModel.polish.privateKey)
        else
        {
            print("Unable to decrypt encrypted receive buffer")
            return nil
        }
        
        // The first two bytes simply lets us know the actual size of the payload
        // This helps account for cases when the payload must be smaller than chunk size
        let payloadSize = Int(decryptedData[..<payloadLengthOverhead].uint16)
        let payload = decryptedData[payloadLengthOverhead..<payloadSize]
        
        // Add decrypted data to the decrypted buffer
        self.decryptedReceiveBuffer.append(payload)
        
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
        if var toneBurst = self.replicantClientModel.toneBurst
        {
            toneBurst.play(connection: self.network)
            {
                maybeError in
                
                guard maybeError == nil else
                {
                    print("ToneBurst failed: \(maybeError!)")
                    return
                }
                
                self.handshake
                {
                    (maybeHandshakeError) in
                    
                    completion(maybeHandshakeError)
                }
            }
        }
        else
        {
            self.handshake
            {
                (maybeHandshakeError) in
                
                completion(maybeHandshakeError)
            }
        }
    }
    
    func handshake(completion: @escaping (Error?) -> Void)
    {
        // Send public key to server
        guard let ourPublicKeyData = self.replicantClientModel.polish.controller.generateAndEncryptPaddedKeyData(
            fromKey: self.replicantClientModel.polish.publicKey,
            withChunkSize: self.replicantClientModel.config.chunkSize,
            usingServerKey: self.replicantClientModel.polish.serverPublicKey)
            else
        {
            print("\nUnable to generate public key data.\n")
            completion(HandshakeError.publicKeyDataGenerationFailure)
            return
        }
        
        self.network.send(content: ourPublicKeyData, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
        {
            (maybeError) in
                
            guard maybeError == nil
                else
            {
                print("\nReceived error from server when sending our key: \(maybeError!)")
                completion(maybeError!)
                return
            }
            
            let replicantChunkSize = Int(self.replicantClientModel.config.chunkSize)
            self.network.receive(minimumIncompleteLength: replicantChunkSize, maximumLength: replicantChunkSize, completion:
            {
                (maybeResponse1Data, maybeResponse1Context, _, maybeResponse1Error) in
                
                guard maybeResponse1Error == nil
                    else
                {
                    print("\nReceived an error while waiting for response from server acfter sending key: \(maybeResponse1Error!)\n")
                    completion(maybeResponse1Error!)
                    return
                }
                
                // This data is meaningless it can be discarded
                guard let _ = maybeResponse1Data
                    else
                {
                    print("\nServer key response did not contain data.\n")
                    completion(nil)
                    return
                }
            })
        }))
    }
    
    func introductions(completion: @escaping (Error?) -> Void)
    {
        voightKampffTest
        {
            (maybeVKError) in
            
            // Set the connection state
            guard let stateHandler = self.stateUpdateHandler
                else
            {
                completion(IntroductionsError.nilStateHandler)
                return
            }
            
            guard maybeVKError == nil
                else
            {
                stateHandler(NWConnection.State.cancelled)
                completion(maybeVKError)
                return
            }
            
            self.handshake(completion:
            {
                (maybeHandshakeError) in
                
                guard maybeHandshakeError == nil
                    else
                {
                    stateHandler(NWConnection.State.cancelled)
                    completion(maybeHandshakeError)
                    return
                }
            })
            
            stateHandler(NWConnection.State.ready)
            completion(nil)
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
        
        guard payloadSize > 0, payloadSize < replicantClientModel.config.chunkSize
        else
        {
            bufferLock.leave()
            return
        }
        
        let payloadData = self.sendBuffer
        let paddingSize = Int(unencryptedChunkSize) - payloadSize
        let padding = Data(repeating: 0, count: paddingSize)
        let dataChunk = UInt16(payloadSize).data + payloadData + padding
        let maybeEncryptedData = self.replicantClientModel.polish.controller.encrypt(payload: dataChunk, usingPublicKey: self.replicantClientModel.polish.serverPublicKey)
        
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
    
}

enum ToneBurstError: Error
{
    case generateFailure
    case removeFailure
}

enum HandshakeError: Error
{
    case publicKeyDataGenerationFailure
    case noClientKeyData
    case invalidClientKeyData
    case missingClientKey
    case clientKeyDataIncorrectSize
    case unableToDecryptData
    case dataCreationError
}

enum IntroductionsError: Error
{
    case nilStateHandler
}
