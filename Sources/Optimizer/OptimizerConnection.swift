//
//  OptimizerConnection.swift
//  Optimizer
//
//  Created by Mafalda on 8/28/19.
//  MIT License
//
//  Copyright (c) 2020 Operator Foundation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Logging
import Transport
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Network
#elseif os(Linux)
import NetworkLinux
#endif


open class OptimizerConnection: Connection
{
    public let log: Logger
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    
    var transportConnection: Connection
    var transport: ConnectionFactory
    let currentStrategy: Strategy
    
    public init?(strategy: Strategy, connectionFactory: ConnectionFactory, logger: Logger,
                 using parameters: NWParameters)
    {
        self.transport = connectionFactory
        self.currentStrategy = strategy
        self.log = logger
        
        guard let newConnection = connectionFactory.connect(using: parameters)
            else
        {
            return nil
        }
        
        self.transportConnection = newConnection
    }
    
    public init(strategy: Strategy, transport: ConnectionFactory, transportConnection: Connection, logger: Logger, using parameters: NWParameters)
    {
        self.transport = transport
        self.transportConnection = transportConnection
        self.currentStrategy = strategy
        self.log = logger
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
                self.log.debug("\n✅  Received ready state for connection.")
                self.currentStrategy.report(transport: self.transport, successfulConnection: true, millisecondsToConnect: Int(connectTime * 1000))
                self.transportConnection.stateUpdateHandler = self.stateUpdateHandler
            case .failed(let error):
                self.log.error("\n🚫  Connection failed: \(error)")
                self.currentStrategy.report(transport: self.transport, successfulConnection: false, millisecondsToConnect: Int(connectTime * 1000))
                self.transportConnection.stateUpdateHandler = self.stateUpdateHandler
            default:
                self.log.debug("\nReceived a state other than ready or failed: \(state)\n")
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
