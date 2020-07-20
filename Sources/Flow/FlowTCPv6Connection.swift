//
//  FlowTCPv6Connection.swift
//  Flow
//
//  Created by Dr. Brandon Wiley on 11/1/18.
//

import Foundation
import Logging
import Network
import Flower
import Transport


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
