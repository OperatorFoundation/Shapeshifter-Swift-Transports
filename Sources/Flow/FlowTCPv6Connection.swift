//
//  FlowTCPv6Connection.swift
//  Flow
//
//  Created by Dr. Brandon Wiley on 11/1/18.
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
import Flower
import Transport

#if os(Linux)
import NetworkLinux
#else
import Network
#endif

open class FlowTCPv6Connection: Connection
{
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    
    let flower: FlowerController
    let endpoint: EndpointV6
    let streamid: StreamIdentifier
    let log: Logger
    
    public init(flower: FlowerController, endpoint: EndpointV6, streamid: StreamIdentifier, logger: Logger)
    {
        self.flower = flower
        self.endpoint = endpoint
        self.streamid = flower.getNextStreamIdentifier()
        self.log = logger
    }
    
    public func start(queue: DispatchQueue)
    {
        let message = Message.TCPOpenV6(endpoint, streamid)
        flower.sendMessage(message: message)
        {
            (maybeError) in
            
            if let error = maybeError
            {
                self.log.error("\(error)")
            }
            
            self.log.debug("Opened stream \(self.streamid)")
        }
    }
    
    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        guard let data = content
            else
        {
            log.error("Received a send command with no content.")
            
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
            default:
                return
            }
            
            return
        }
        
        let message = Message.TCPData(streamid, data)
        flower.sendMessage(message: message)
        {
            (maybeError) in
            
            if let error = maybeError
            {
                self.log.error("\(error)")
            }
            
            switch completion
            {
            case .contentProcessed(let handler):
                handler(maybeError)
            default:
                return
            }
        }
    }
    
    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        self.receive(minimumIncompleteLength: 1, maximumLength: 1000000, completion: completion)
    }
    
    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        flower.receiveMessage(streamid: streamid)
        {
            (maybeMessage) in
            
            guard let message = maybeMessage else
            {
                return
            }
            
            guard case let Message.TCPData(_, data) = message else
            {
                return
            }
            
            completion(data, nil, false, nil)
        }
    }
    
    public func cancel()
    {
        flower.cancel(streamid: streamid)
        
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
