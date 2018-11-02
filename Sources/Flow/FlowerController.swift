//
//  FlowConnectionMetaFactory.swift
//  Flow
//
//  Created by Dr. Brandon Wiley on 11/1/18.
//

import Foundation
import Transport
import Network
import Flower

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
    var nextStreamIdentifier: StreamIdentifier = 0
    var streams: [StreamIdentifier:Connection] = [:]
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, parameters: NWParameters)
    {
        self.connection = NWConnection(host: host, port: port, using: parameters)
    }
    
    public init(connection: Connection)
    {
        self.connection = connection
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
                let conn = FlowUDPv4Connection(flower: self, endpoint: dst, streamid: streamid)
                streams[streamid] = conn
                return conn
            case (.UDP, .v6):
                guard case let .ipv6(address) = host else
                {
                    return nil
                }
                
                let dst = EndpointV6(host: address, port: port)
                let conn = FlowUDPv6Connection(flower: self, endpoint: dst, streamid: streamid)
                streams[streamid] = conn
                return conn
            case (.TCP, .v4):
                guard case let .ipv4(address) = host else
                {
                    return nil
                }

                let dst = EndpointV4(host: address, port: port)
                let conn = FlowTCPv4Connection(flower: self, endpoint: dst, streamid: streamid)
                streams[streamid] = conn
                return conn
            case (.TCP, .v6):
                guard case let .ipv6(address) = host else
                {
                    return nil
                }
                
                let dst = EndpointV6(host: address, port: port)
                let conn = FlowTCPv6Connection(flower: self, endpoint: dst, streamid: streamid)
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
                    
                    print("Closed stream \(streamid)")
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
        case .ipv4(_):
            return .v4
        case .ipv6(_):
            return .v6
        case .name(_, _):
            return .named
    }
}
