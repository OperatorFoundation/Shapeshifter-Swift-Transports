//
//  OptimizerConnection.swift
//  Optimizer
//
//  Created by Mafalda on 8/28/19.
//

import Foundation
import Transport
import Network

open class OptimizerConnection: Connection
{
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    
    var transportConnection: Connection
    var transport: ConnectionFactory
    let currentStrategy: Strategy
    
    public init?(strategy: Strategy, connectionFactory: ConnectionFactory,
                 using parameters: NWParameters)
    {
        self.transport = connectionFactory
        self.currentStrategy = strategy
        
        guard let newConnection = connectionFactory.connect(using: parameters)
            else
        {
            return nil
        }
        
        self.transportConnection = newConnection
    }
    
    public init(strategy: Strategy, transport: ConnectionFactory, transportConnection: Connection, using parameters: NWParameters)
    {
        self.transport = transport
        self.transportConnection = transportConnection
        self.currentStrategy = strategy
    }
    
    public func start(queue: DispatchQueue)
    {
        let preConnectionDate = Date()

        transportConnection.stateUpdateHandler =
        {
            state in

            let connectTime = Date().timeIntervalSince(preConnectionDate)

            switch state
            {
            case .ready:
                print("\n✅  Received ready state for connection.")
                self.currentStrategy.report(transport: self.transport, successfulConnection: true, millisecondsToConnect: Int(connectTime * 1000))
                self.transportConnection.stateUpdateHandler = self.stateUpdateHandler
            case .failed(let error):
                print("\n🚫  Connection failed: \(error)")
                self.currentStrategy.report(transport: self.transport, successfulConnection: false, millisecondsToConnect: Int(connectTime * 1000))
                self.transportConnection.stateUpdateHandler = self.stateUpdateHandler
            default:
                print("\nReceived a state other than ready or failed: \(state)\n")
                self.transportConnection.stateUpdateHandler = self.stateUpdateHandler
            }


        }
        
        transportConnection.start(queue: queue)
    }
    
    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        transportConnection.send(content: content, contentContext: contentContext, isComplete: isComplete, completion: completion)
    }
    
    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        transportConnection.receive(completion: completion)
    }
    
    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        transportConnection.receive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, completion: completion)
    }
    
    public func cancel()
    {
        transportConnection.cancel()
    }
}