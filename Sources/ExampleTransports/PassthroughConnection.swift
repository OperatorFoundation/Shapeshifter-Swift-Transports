//
//  PassthroughConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/30/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import Logging
import Transport
import Network

open class PassthroughConnection: Connection
{
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    
    let log: Logger
    var network: Connection

    public init?(host: NWEndpoint.Host,
                 port: NWEndpoint.Port,
                 using parameters: NWParameters,
                 logger: Logger)
    {
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        guard let newConnection = connectionFactory.connect(using: parameters)
        else
        {
            return nil
        }
        
        network = newConnection
        log = logger
    }
    
    public init(connection: Connection, using parameters: NWParameters, logger: Logger)
    {
        network = connection
        log = logger
    }
    
    public func start(queue: DispatchQueue)
    {
        network.start(queue: queue)
    }
    
    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        network.send(content: content, contentContext: contentContext, isComplete: isComplete, completion: completion)
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
