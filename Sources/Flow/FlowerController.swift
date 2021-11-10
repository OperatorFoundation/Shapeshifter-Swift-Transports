//
//  FlowConnectionMetaFactory.swift
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

import Net

enum StreamType
{
    case UDP
    case TCP
}

enum AddressType
{
    case v6
    case v4
    case named
}

public class FlowerController
{
    let connection: Connection
    let log: Logger
    var nextStreamIdentifier: StreamIdentifier = 0
    var streams: [StreamIdentifier:Connection] = [:]
    
    public init?(host: NWEndpoint.Host, port: NWEndpoint.Port, parameters: NWParameters, logger: Logger)
    {
        self.log = logger

        guard let connection = NWConnection(host: host, port: port, using: parameters) else {return nil}
        self.connection = connection
    }
    
    public init(connection: Connection, logger: Logger)
    {
        self.connection = connection
        self.log = logger
    }
    
    public func connect(host: NWEndpoint.Host, port: NWEndpoint.Port, using parameters: NWParameters) -> Connection?
    {
        let streamid = StreamIdentifier.random(in: 0..<StreamIdentifier.max)
        let streamtype = determineStreamType(parameters: parameters)
        let addresstype = determineAddressType(host: host)
        switch (streamtype, addresstype)
        {
            case (.UDP, .v4):
                guard case let NWEndpoint.Host.ipv4(address) = host else
                {
                    return nil
                }
                
                let dst = EndpointV4(host: address, port: port)
                let conn = FlowUDPv4Connection(flower: self, endpoint: dst, streamid: streamid, logger: log)
                streams[streamid] = conn
                return conn
            case (.UDP, .v6):
                guard case let .ipv6(address) = host else
                {
                    return nil
                }
                
                let dst = EndpointV6(host: address, port: port)
                let conn = FlowUDPv6Connection(flower: self, endpoint: dst, streamid: streamid, logger: log)
                streams[streamid] = conn
                return conn
            case (.TCP, .v4):
                guard case let .ipv4(address) = host else
                {
                    return nil
                }

                let dst = EndpointV4(host: address, port: port)
                let conn = FlowTCPv4Connection(flower: self, endpoint: dst, streamid: streamid, logger: log)
                streams[streamid] = conn
                return conn
            case (.TCP, .v6):
                guard case let .ipv6(address) = host else
                {
                    return nil
                }
                
                let dst = EndpointV6(host: address, port: port)
                let conn = FlowTCPv6Connection(flower: self, endpoint: dst, streamid: streamid, logger: log)
                streams[streamid] = conn
                return conn
            default:
                return nil
        }
    }
    
    public func getNextStreamIdentifier() -> StreamIdentifier
    {
        let result = nextStreamIdentifier
        nextStreamIdentifier += 1
        return result
    }
    
    public func sendMessage(message: Message, completion: @escaping (NWError?) -> Void)
    {
        connection.writeMessage(message: message)
        {
            (maybeError) in
            
            completion(maybeError)
        }
    }
    
    public func receiveMessage(streamid: StreamIdentifier, completion: @escaping (Message?) -> Void)
    {
        
    }
    
    public func cancel(streamid: UInt64)
    {
        guard let conn = streams[streamid] else
        {
            return
        }
        
        streams.removeValue(forKey: streamid)
        
        switch conn
        {
            case is FlowTCPv4Connection, is FlowTCPv6Connection:
                let close = Message.TCPClose(streamid)
                sendMessage(message: close)
                {
                    (maybeError) in
                    
                    if let error = maybeError
                    {
                        self.log.error("\(error)")
                    }
                    
                    self.log.debug("Closed stream \(streamid)")
                }
            default:
                return
        }
    }
}

func determineStreamType(parameters: NWParameters) -> StreamType
{
    guard let prot = parameters.defaultProtocolStack.transportProtocol
        else
    {
        return .TCP
    }
    
    guard let _ = prot as? NWProtocolUDP.Options
        else
    {
        return .UDP
    }
    
    return .TCP
}

func determineAddressType(host: NWEndpoint.Host) -> AddressType
{
    switch host
    {
        case .ipv4:
            return .v4
        case .ipv6:
            return .v6
	default:
	    return .named
    }
}
