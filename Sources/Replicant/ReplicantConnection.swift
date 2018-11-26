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
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var config: ReplicantConfig
    public var replicant: Replicant
    
    var networkQueue = DispatchQueue(label: "Replicant Queue")
    var network: Connection
    
    public init?(host: NWEndpoint.Host,
                 port: NWEndpoint.Port,
                 using parameters: NWParameters,
                 and config: ReplicantConfig)
    {
        guard let prot = parameters.defaultProtocolStack.internetProtocol, let _ = prot as? NWProtocolTCP.Options
            else
        {
            print("Attempted to initialize Replicant not as a TCP connection.")
            return nil
        }
        
        guard let newReplicant = Replicant(withConfig: config)
        else
        {
            print("\nFailed to initialize ReplicantConnection because we failed to initialize Replicant.\n")
            return nil
        }
        
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        guard let newConnection = connectionFactory.connect(using: parameters)
            else
        {
            return nil
        }
        
        self.network = newConnection
        self.config = config
        self.replicant = newReplicant
    }
    
    public init?(connection: Connection,
                using parameters: NWParameters,
                and config: ReplicantConfig)
    {
        guard let prot = parameters.defaultProtocolStack.internetProtocol, let _ = prot as? NWProtocolTCP.Options
            else
        {
            print("Attempted to initialize Replicant not as a TCP connection.")
            return nil
        }
        
        guard let newReplicant = Replicant(withConfig: config)
        else
        {
            print("\nFailed to initialize ReplicantConnection because we failed to initialize Replicant.\n")
            return nil
        }
        
        self.network = connection
        self.config = config
        self.replicant = newReplicant
    }
    
    public func start(queue: DispatchQueue)
    {
        network.stateUpdateHandler = self.stateUpdateHandler
        network.start(queue: queue)
    }
    
    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
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
        
        let maybeEncryptedData = replicant.encryptor.encrypt(payload: someData, usingServerKey: replicant.serverPublicKey)
        
        network.send(content: maybeEncryptedData, contentContext: contentContext, isComplete: isComplete, completion: completion)
    }
    
    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        self.receive(minimumIncompleteLength: 1, maximumLength: 1000000, completion: completion)
    }
    
    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        network.receive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength)
        { (maybeData, maybeContext, connectionComplete, maybeError) in
            
            guard let someData = maybeData
                else
            {
                print("\nReceive called with no content.\n")
                completion(maybeData, maybeContext, connectionComplete, maybeError)
                return
            }
            
            let decryptedData = self.replicant.encryptor.decrypt(payload: someData, usingPrivateKey: self.replicant.clientPrivateKey)
            
            completion(decryptedData, maybeContext, connectionComplete, maybeError)
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
    
    /// This is basically pseudo code. Working on it ;)
    func voightKampffTest()
    {
        // Tone Burst
        self.toneBurst()
        
        // Send public key to server
        guard let ourPublicKeyData = replicant.encryptor.generateAndEncryptPaddedKeyData(fromKey: replicant.clientPublicKey, withChunkSize: replicant.config.chunkSize, usingServerKey: replicant.serverPublicKey)
        else
        {
            print("\nUnable to generate public key data.\n")
            return
        }
        
        network.send(content: ourPublicKeyData, contentContext: .defaultMessage, isComplete: true, completion: NWConnection.SendCompletion.contentProcessed(
        { (maybeError) in
            
            guard maybeError == nil
            else
            {
                print("\nReceived error from server when sending our key: \(maybeError!)")
                return
            }
            
            let replicantChunkSize = self.replicant.config.chunkSize
            self.network.receive(minimumIncompleteLength: replicantChunkSize, maximumLength: replicantChunkSize, completion:
            {
                (maybeResponse1Data, maybeResponse1Context, _, maybeResponse1Error) in
                
                guard maybeResponse1Error == nil
                    else
                {
                    print("\nReceived an error while waiting for response from server acfter sending key: \(maybeResponse1Error!)\n")
                    return
                }
                
                // This data is meaningless it can be discarded
                guard let _ = maybeResponse1Data
                    else
                {
                    print("\nServer key response did not contain data.\n")
                    return
                }
                
            })
        }))
        
        network.start(queue: networkQueue)
    }
    
    func toneBurst()
    {
        guard let toneBurst = replicant.toneBurst
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
            handleToneExchange(nextTone: nextTone, finalTone: false)
            
        case .completion(let lastTone):
            print("\nGenerated final toneburst\n")
            handleToneExchange(nextTone: lastTone, finalTone: true)
            
        case .failure:
            print("\nFailed to generate requested ToneBurst")
            return
        }
    }
    
    func handleToneExchange(nextTone: Data, finalTone: Bool)
    {
        guard let toneBurst = replicant.toneBurst
            else
        {
            print("\nOur instance of Replicant does not have a ToneBurst instance.\n")
            return
        }
        
        network.send(content: nextTone, contentContext: .defaultMessage, isComplete: finalTone, completion: NWConnection.SendCompletion.contentProcessed(
            {
                (maybeToneSendError) in
                
                guard maybeToneSendError == nil
                    else
                {
                    print("Received error while sending tone burst: \(maybeToneSendError!)")
                    return
                }
                
                let toneLength = self.replicant.
                self.network.receive(minimumIncompleteLength: <#T##Int#>, maximumLength: <#T##Int#>, completion: <#T##(Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void#>)
                self.network.receive(completion:
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
                        case .completion(let receivedData):
                            // FIXME: Do something with returned data
                            if !finalTone
                            {
                                self.toneBurst()
                            }
                            
                        case .waiting:
                            // FIXME: Decide what to do here
                            return
                            
                        case .failure:
                            print("\nTone burst remove failure.\n")
                            return
                        }
                })
        }))
    }
    
}
