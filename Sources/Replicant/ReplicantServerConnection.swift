//
//  ReplicantServerConnection.swift
//  Replicant
//
//  Created by Adelita Schule on 12/3/18.
//

import Foundation
import Network

import Transport
import ReplicantSwift

open class ReplicantServerConnection: Connection
{
    // FIXME: Constants called out twice, should be global
    public let aesOverheadSize = 81
    public let payloadLengthOverhead = 2
    
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var replicantConfig: ReplicantServerConfig
    public var replicantServerModel: ReplicantServerModel
    
    let unencryptedChunkSize: UInt16
    
    var sendTimer: Timer?
    var dispatchGroup = DispatchGroup()
    var networkQueue = DispatchQueue(label: "Replicant Queue")
    var sendBufferQueue = DispatchQueue(label: "SendBuffer Queue")
    var network: Connection
    var sendBuffer = Data()
    var decryptedReceiveBuffer = Data()
    
    public init?(connection: Connection,
                 using parameters: NWParameters,
                 andReplicantConfig replicantConfig: ReplicantServerConfig)
    {
        guard let prot = parameters.defaultProtocolStack.internetProtocol, let _ = prot as? NWProtocolTCP.Options
            else
        {
            print("Attempted to initialize Replicant not as a TCP connection.")
            return nil
        }
        
        guard let newReplicant = ReplicantServerModel(withConfig: replicantConfig)
            else
        {
            print("\nFailed to initialize ReplicantConnection because we failed to initialize Replicant.\n")
            return nil
        }
        
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
        // Lock so that the timer cannot fire and change the buffer
        dispatchGroup.enter()
        
        guard let someData = content
            else
        {
            print("Received a send command with no content.")
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
            default:
                dispatchGroup.leave()
                return
            }
            
            dispatchGroup.leave()
            return
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
                dispatchGroup.leave()
                return
            default:
                dispatchGroup.leave()
                return
            }
        }
        
        guard let clientPublicKey = self.replicantServerModel.polish.clientPublicKey
        else
        {
            print("Received a send command when we do not yet have the client's public key.")
            switch completion
            {
            case .contentProcessed(let handler):
                handler(NWError.posix(POSIXErrorCode.ENOATTR))
                dispatchGroup.leave()
                return
            default:
                dispatchGroup.leave()
                return
            }
        }
        
        let payloadData = self.sendBuffer[0 ..< unencryptedChunkSize]
        let payloadSize = UInt16(unencryptedChunkSize)
        let dataChunk = payloadSize.data + payloadData
        let maybeEncryptedData = self.replicantServerModel.polish.controller.encrypt(payload: dataChunk, usingPublicKey: clientPublicKey)
        
        // Buffer should only contain unsent data
        self.sendBuffer = self.sendBuffer[unencryptedChunkSize...]
        
        // Turn off the timer
        self.sendTimer!.invalidate()
        self.sendTimer = nil
        
        // Keep calling network.send if the leftover data is at least chunk size
        self.network.send(content: maybeEncryptedData, contentContext: contentContext, isComplete: isComplete, completion: NWConnection.SendCompletion.contentProcessed(
            { (maybeError) in
                
                if let error = maybeError
                {
                    print("Received an error on Send:\(error)")
                    self.sendTimer!.invalidate()
                    self.sendTimer = nil
                    
                    switch completion
                    {
                    case .contentProcessed(let handler):
                        handler(error)
                        self.dispatchGroup.leave()
                        return
                    default:
                        self.dispatchGroup.leave()
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
                        self.dispatchGroup.leave()
                        return
                    default:
                        self.dispatchGroup.leave()
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
        }
        else
        {
            network.receive(minimumIncompleteLength: Int(replicantServerModel.config.chunkSize), maximumLength: Int(replicantServerModel.config.chunkSize))
            { (maybeData, maybeContext, connectionComplete, maybeError) in
                
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
        guard let decryptedData = self.replicantServerModel.polish.controller.decrypt(payload: encryptedData, usingPrivateKey: self.replicantServerModel.polish.privateKey)
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
    
    func voightKampffTest(completion: @escaping (Error?) -> Void)
    {
        // Tone Burst
        self.toneBurstReceive(finalToneSent: false)
        {
            (maybeError) in
            
            guard maybeError == nil
                else
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
    
    func toneBurstSend(completion: @escaping (Error?) -> Void)
    {
        guard let toneBurst = replicantServerModel.toneBurst
            else
        {
            print("\nOur instance of Replicant does not have a ToneBurst instance.\n")
            return
        }
        
        let sendState = toneBurst.generate()
        
        switch sendState
        {
            case .generating(let nextTone):
                print("\nGenerating tone bursts.\n")
                network.send(content: nextTone, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
                {
                    (maybeToneSendError) in
                    
                    guard maybeToneSendError == nil
                        else
                    {
                        print("Received error while sending tone burst: \(maybeToneSendError!)")
                        return
                    }
                    
                    self.toneBurstReceive(finalToneSent: false, completion: completion)
                }))
            
            case .completion:
                print("\nGenerated final toneburst\n")
                toneBurstReceive(finalToneSent: true, completion: completion)
            
            case .failure:
                print("\nFailed to generate requested ToneBurst")
                completion(ToneBurstError.generateFailure)
        }
    }
    
    func toneBurstReceive(finalToneSent: Bool, completion: @escaping (Error?) -> Void)
    {
        guard let toneBurst = replicantServerModel.toneBurst
            else
        {
            print("\nOur instance of Replicant does not have a ToneBurst instance.\n")
            return
        }
        
        guard let toneLength = self.replicantServerModel.toneBurst?.nextRemoveSequenceLength
            else
        {
            // Tone burst is finished
            return
        }
        
        self.network.receive(minimumIncompleteLength: Int(toneLength), maximumLength: Int(toneLength) , completion:
        {
            (maybeToneResponseData, maybeToneResponseContext, connectionComplete, maybeToneResponseError) in
            
            guard maybeToneResponseError == nil
                else
            {
                print("\nReceived an error in the server tone response: \(maybeToneResponseError!)\n")
                return
            }
            
            guard let toneResponseData = maybeToneResponseData
                else
            {
                print("\nTone response was empty.\n")
                return
            }
            
            let receiveState = toneBurst.remove(newData: toneResponseData)
            
            switch receiveState
            {
            case .completion:
                if !finalToneSent
                {
                    self.toneBurstSend(completion: completion)
                }
                else
                {
                    completion(nil)
                }
                
            case .receiving:
                self.toneBurstSend(completion: completion)
                
            case .failure:
                print("\nTone burst remove failure.\n")
                completion(ToneBurstError.removeFailure)
            }
        })
    }
    
    func handshake(completion: @escaping (Error?) -> Void)
    {
        let replicantChunkSize = self.replicantServerModel.config.chunkSize
        let keySize = 64
        let keyDataSize = keySize + 1
        
        //Call receive first
        self.network.receive(minimumIncompleteLength: Int(replicantChunkSize), maximumLength: Int(replicantChunkSize), completion:
        {
            (maybeResponse1Data, maybeResponse1Context, _, maybeResponse1Error) in
            
            // Parse received public key and store it
            guard maybeResponse1Error == nil
            else
            {
                print("\nReceived an error while waiting for response from server acfter sending key: \(maybeResponse1Error!)\n")
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
            
            // Decrypt the received data
            guard let clientPaddedKey = self.replicantServerModel.polish.controller.decrypt(payload: clientEncryptedData, usingPrivateKey: self.replicantServerModel.polish.privateKey)
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
        })
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
        // Respect the lock
        dispatchGroup.wait()
        
        // Lock so that send isn't called while we're working
        dispatchGroup.enter()
        
        self.sendTimer = nil
        
        // Double check the buffer to be sure that there is still data in there.
        print("\n⏰  Chunk Timeout Reached\n  ⏰")
        
        let payloadSize = sendBuffer.count
        
        guard payloadSize > 0, payloadSize < replicantServerModel.config.chunkSize
            else
        {
            dispatchGroup.leave()
            return
        }
        
        guard let clientPublicKey = self.replicantServerModel.polish.clientPublicKey
            else
        {
            print("Received a send command when we do not yet have the client's public key.")
            dispatchGroup.leave()
            return
        }
        
        let payloadData = self.sendBuffer
        let paddingSize = Int(unencryptedChunkSize) - payloadSize
        let padding = Data(repeating: 0, count: paddingSize)
        let dataChunk = UInt16(payloadSize).data + payloadData + padding
        let maybeEncryptedData = self.replicantServerModel.polish.controller.encrypt(payload: dataChunk, usingPublicKey: clientPublicKey)
        
        // Buffer should only contain unsent data
        self.sendBuffer = Data()
        
        // Keep calling network.send if the leftover data is at least chunk size
        self.network.send(content: maybeEncryptedData, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
        { (maybeError) in
            
            if let error = maybeError
            {
                print("Received an error on Send:\(error)")
                
                self.dispatchGroup.leave()
                return
            }
            
            self.dispatchGroup.leave()
        }))
    }
    
}
