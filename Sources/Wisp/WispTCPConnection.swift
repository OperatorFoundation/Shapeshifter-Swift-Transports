//
//  WispTCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/30/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//
// The Wisp transport protocol is wire-compatible with the obfs4 transport and can use obfs4 servers as
// well as obfs4 configuration parameters.
//
// Wisp is a new implementaiton of the obfs4 protocol and is not guaranteed to be identical in
// implementation to other obfs4 implementations except when required for over-the-wire compatibility.

import Foundation
import NetworkExtension
import ShapeshifterTesting

let certKey = "cert"
let iatKey = "iatMode"

func createWispTCPConnection(provider: PacketTunnelProvider, to: NWEndpoint, cert: String, iatMode: Bool) -> WispTCPConnection?
{
    return WispTCPConnection(provider: provider as! NEPacketTunnelProvider, to: to, cert: cert, iatMode: iatMode)
}

func createWispTCPConnection(connection: NWTCPConnection, cert: String, iatMode: Bool) -> WispTCPConnection?
{
    return WispTCPConnection(connection: connection, cert: cert, iatMode: iatMode)
}

class WispTCPConnection: NWTCPConnection
{
    var network: NWTCPConnection
    var writeClosed = false
    
    var wisp: WispProtocol
    var handshakeDone = false
    
    override var state: NWTCPConnectionState
    {
        get
        {
            return network.state
        }
    }
    
    override var isViable: Bool
    {
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
    
    convenience init?(provider: NEPacketTunnelProvider, to: NWEndpoint, cert: String, iatMode: Bool)
    {
        let connection = provider.createTCPConnectionThroughTunnel(to: to, enableTLS: true, tlsParameters: nil, delegate: nil)
        
        self.init(connection: connection, cert: cert, iatMode: iatMode)
    }
    
    init?(connection: NWTCPConnection, cert: String, iatMode: Bool)
    {
        network = connection
        
        guard let newWisp = WispProtocol(connection: network, cert: cert, iatMode: iatMode)
            else
        {
            return nil
        }
        
        wisp = newWisp
        super.init()
        
        wisp.connectWithHandshake(certString: cert, sessionKey: wisp.sessionKey)
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("Error connecting with handshake: \(error)")
                self.handshakeDone = false
            }
            else
            {
                self.handshakeDone = true
            }
        }
    }
    
    override func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        wisp.readPackets(minRead: minimum, maxRead: maximum)
        {
            (maybeDecodedData, maybeError) in
            
            guard maybeError == nil
            else
            {
                completion(nil, maybeError)
                return
            }
            
            guard let decodedData = maybeDecodedData
            else
            {
                completion(nil, nil)
                return
            }
            
            completion(decodedData, nil)
        }
    }
    
    override func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        readMinimumLength(length, maximumLength: length, completionHandler: completion)
    }
    
    override func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
        guard let frame = wisp.encoder?.encode(payload: data)
        else
        {
            print("Failed to encoded data while attempting to WispTCPConnection write.")
            completion(nil)
            return
        }
        
        network.write(frame)
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
