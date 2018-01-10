//
//  PassthroughTCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/30/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

func createPassthroughTCPConnection(provider: NEPacketTunnelProvider, to: NWEndpoint) -> PassthroughTCPConnection
{
    return PassthroughTCPConnection(provider: provider, to: to)
}

func createPassthroughTCPConnection(connection: TCPConnection) -> PassthroughTCPConnection
{
    return PassthroughTCPConnection(connection: connection)
}

class PassthroughTCPConnection: TCPConnection
{
    var network: TCPConnection
    var writeClosed = false
    
    override var state: NWTCPConnectionState {
        get {
            return network.state
        }
    }
    
    override var isViable: Bool {
        get {
            return network.isViable
        }
    }
    
    override var error: Error? {
        get {
            return network.error
        }
    }
    
    override var endpoint: NWEndpoint {
        get {
            return network.endpoint
        }
    }
    
    override var remoteAddress: NWEndpoint? {
        get {
            return network.remoteAddress
        }
    }
    
    override var localAddress: NWEndpoint? {
        get {
            return network.localAddress
        }
    }
    
    override var connectedPath: NWPath? {
        get {
            return network.connectedPath
        }
    }
    
    override var txtRecord: Data? {
        get {
            return network.txtRecord
        }
    }
    
    override var hasBetterPath: Bool {
        get {
            return network.hasBetterPath
        }
    }
    
    init(provider: NEPacketTunnelProvider, to: NWEndpoint) {
        network = provider.createTCPConnectionThroughTunnel(to: to, enableTLS: true, tlsParameters: nil, delegate: nil)
        
        super.init()
    }
    
    init(connection: TCPConnection) {
        network = connection
        
        super.init()
    }
    
    override func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        network.readMinimumLength(minimum, maximumLength: maximum)
        {
            (maybeData, maybeError) in
            
            guard maybeError == nil else
            {
                completion(nil, maybeError!)
                return
            }
            
            guard let data = maybeData else
            {
                completion(nil, nil)
                return
            }
            
            completion(data, nil)
        }
    }
    
    override func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        readMinimumLength(length, maximumLength: length, completionHandler: completion)
    }
    
    override func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
        network.write(data)
        {
            (error) in
            
            completion(error)
        }
    }
    
    override func writeClose()
    {
        network.writeClose()
    }
    
    override func cancel()
    {
        network.cancel()
    }
}
