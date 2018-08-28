//
//  ProteanConnection.swift
//  Protean
//
//  Created by Adelita Schule on 8/24/18.
//

import Foundation
import Transport
import Network
import ProteanSwift

open class ProteanConnection: Connection
{
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var config: Protean.Config
    
    var network: Connection
    
    public init?(host: NWEndpoint.Host,
                 port: NWEndpoint.Port,
                 config: Protean.Config,
                 using parameters: NWParameters)
    {
        guard let prot = parameters.defaultProtocolStack.internetProtocol, let _ = prot as? NWProtocolUDP.Options
            else
        {
            print("Attempted to initialize protean not as a UDP connection.")
           return nil
        }

        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        guard let newConnection = connectionFactory.connect(.udp)
        else
        {
            return nil
        }
        
        self.config = config
        self.network = newConnection
    }
    
    public init?(connection: Connection,
                 config: Protean.Config,
                 using parameters: NWParameters)
    {
        guard let prot = parameters.defaultProtocolStack.internetProtocol, let _ = prot as? NWProtocolUDP.Options
            else
        {
            print("Attempted to initialize protean not as a UDP connection.")
            return nil
        }
        
        self.config = config
        self.network = connection
    }
    
    public func start(queue: DispatchQueue)
    {
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
        
        let proteanTransformer = Protean(config: config)
        let transformedDatas = proteanTransformer.transform(buffer: someData)
        guard !transformedDatas.isEmpty, let transformedData = transformedDatas.first
        else
        {
            print("Received empty response on call to Protean.Transform")
            
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
            default:
                return
            }
            
            return
        }
        
        network.send(content: transformedData, contentContext: contentContext, isComplete: isComplete, completion: completion)
    }
    
    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        network.receive(completion: completion)
    }
    
    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        network.receive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, completion: completion)
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
}
