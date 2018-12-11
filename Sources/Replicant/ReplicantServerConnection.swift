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
    public let aesOverheadSize = 81
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    
    //FIXME: Server Config
    public var config: ReplicantServerConfig
    public var replicantServer: ReplicantServer
    
    var networkQueue = DispatchQueue(label: "Replicant Queue")
    var network: Connection
    var sendBuffer = Data()
    var decryptedReceiveBuffer = Data()
    
    public init?(connection: Connection,
                 using parameters: NWParameters,
                 and config: ReplicantServerConfig)
    {
        ///FIXME: Use server config
        
        guard let prot = parameters.defaultProtocolStack.internetProtocol, let _ = prot as? NWProtocolTCP.Options
            else
        {
            print("Attempted to initialize Replicant not as a TCP connection.")
            return nil
        }
        
        guard let newReplicant = ReplicantServer(withConfig: config)
            else
        {
            print("\nFailed to initialize ReplicantConnection because we failed to initialize Replicant.\n")
            return nil
        }
        
        self.network = connection
        self.config = config
        self.replicantServer = newReplicant
        
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
        
        //FIXME: Make sure we are using the correct keys
        guard let someData = content
            else
        {
            print("Received a send command with no content.")
            
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
            default:
                return
            }
            
            return
        }
        
        guard let recipientPublicKey = replicantServer.polish.recipientPublicKey
        else
        {
            print("Received a send command but we do not have the recipient public key.")
            
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
            default:
                return
            }
            
            return
        }
        
        sendBuffer.append(someData)
        
        // Only encrypt and send over network when chunk size is available, leftovers to the buffer
        let unencryptedChunkSize = self.replicantServer.config.chunkSize - aesOverheadSize
        guard sendBuffer.count >= (unencryptedChunkSize)
            else
        {
            print("Received a send command with content less than chunk size.")
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
            default:
                return
            }
            
            return
        }
        
        let dataChunk = sendBuffer[0 ..< unencryptedChunkSize]
        let maybeEncryptedData = replicantServer.polish.encrypt(payload: dataChunk, usingPublicKey: recipientPublicKey)
        
        // Buffer should only contain unsent data
        sendBuffer = sendBuffer[unencryptedChunkSize...]
        
        network.send(content: maybeEncryptedData, contentContext: contentContext, isComplete: isComplete, completion: completion)
    }
    
    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        self.receive(minimumIncompleteLength: 1, maximumLength: 1000000, completion: completion)
    }
    
    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        //FIXME: Make sure we are using the correct keys
        
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
            network.receive(minimumIncompleteLength: replicantServer.config.chunkSize, maximumLength: replicantServer.config.chunkSize)
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
        //FIXME: Make sure we are using the correct keys
        
        // Try to decrypt the entire contents of the encrypted buffer
        guard let decryptedData = self.replicantServer.polish.decrypt(payload: encryptedData, usingPrivateKey: self.replicantServer.polish.privateKey)
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
        //FIXME Call receive instead
        // Tone Burst
        self.toneBurstSend
            { (maybeError) in
                
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
        guard let toneBurst = replicantServer.toneBurst
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
        guard let toneBurst = replicantServer.toneBurst
            else
        {
            print("\nOur instance of Replicant does not have a ToneBurst instance.\n")
            return
        }
        
        guard let toneLength = self.replicantServer.toneBurst?.nextRemoveSequenceLength
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
        let replicantChunkSize = self.replicantServer.config.chunkSize
        let keySize = 64
        let keyDataSize = keySize + 1
        
        //Call receive first
        self.network.receive(minimumIncompleteLength: replicantChunkSize, maximumLength: replicantChunkSize, completion:
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
            
            guard let clientEncryptedData = maybeResponse1Data
            else
            {
                print("\nClient introduction did not contain data.\n")
                completion(HandshakeError.noClientKeyData)
                return
            }
            
            guard let clientPaddedKey = self.replicantServer.polish.decrypt(payload: clientEncryptedData, usingPrivateKey: self.replicantServer.polish.privateKey)
            else
            {
                print("\nCould not decrypt client introduction.\n")
                completion(HandshakeError.unableToDecryptData)
                return
            }
            
            guard clientPaddedKey.count >= keyDataSize
            else
            {
                print("\nReceived a client key that is \(clientPaddedKey.count), but it should have been \(keyDataSize)\n")
                completion(HandshakeError.clientKeyDataIncorrectSize)
                return
            }
            
            let clientKeyData = clientPaddedKey[0 ..< keyDataSize]
            
            //FIXME: Will decode key method account for leading 04?
            guard let clientKey = Polish.decodeKey(fromData: clientKeyData)
            else
            {
                print("\nUnable to decode client key.\n")
                completion(HandshakeError.invalidClientKeyData)
                return
            }
            
            self.replicantServer.polish.recipientPublicKey = clientKey
            
            //FIXME: Generate random data of chunk size
            let randomData = Data()
            
            //FIXME: Send random data to client
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
    
}
