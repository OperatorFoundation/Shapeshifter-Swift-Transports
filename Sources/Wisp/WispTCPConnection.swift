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
import Transport

let certKey = "cert"
let iatKey = "iatMode"

func createWispTCPConnection(provider: PacketTunnelProvider, to: NWEndpoint, cert: String, iatMode: Bool) -> WispTCPConnection?
{
    return WispTCPConnection(provider: provider, to: to, cert: cert, iatMode: iatMode)
}

func createWispTCPConnection(connection: TCPConnection, cert: String, iatMode: Bool) -> WispTCPConnection?
{
    return WispTCPConnection(connection: connection, cert: cert, iatMode: iatMode)
}

class WispTCPConnection: TCPConnection
{
    var network: TCPConnection
    var writeClosed = false
    var wisp: WispProtocol
    var handshakeDone = false
    var stateCallback: ((NWTCPConnectionState, Error?) -> Void)?
    
    private var _isViable: Bool
    private var _error: Error?
    private var _state: NWTCPConnectionState
    {
        didSet
        {
            NotificationCenter.default.post(name: .wispConnectionState, object: _state)
            guard let callback = stateCallback
            else { return }
            
            callback(_state, nil)
        }
    }
    
    var state: NWTCPConnectionState
    {
        get {
            return _state
        }
    }
    
    var isViable: Bool
    {
        get {
            return _isViable
        }
    }
    
    var error: Error? {
        get {
            return _error
        }
    }
    
    var endpoint: NWEndpoint {
        get {
            return network.endpoint
        }
    }
    
    var remoteAddress: NWEndpoint? {
        get {
            return network.remoteAddress
        }
    }
    
    var localAddress: NWEndpoint? {
        get {
            return network.localAddress
        }
    }
    
    var connectedPath: NWPath? {
        get {
            return network.connectedPath
        }
    }
    
    var txtRecord: Data? {
        get {
            return network.txtRecord
        }
    }
    
    var hasBetterPath: Bool {
        get {
            return network.hasBetterPath
        }
    }
    
    convenience init?(provider: PacketTunnelProvider, to: NWEndpoint, cert: String, iatMode: Bool)
    {
        guard let connection = provider.createTCPConnectionThroughTunnel(to: to, enableTLS: true, tlsParameters: nil, delegate: nil)
        else
        {
            return nil
        }

        self.init(connection: connection, cert: cert, iatMode: iatMode)
    }
    
    init?(connection: TCPConnection, cert: String, iatMode: Bool)
    {
        network = connection
        _isViable = false
        _state = .connecting
        
        guard let newWisp = WispProtocol(connection: network, cert: cert, iatMode: iatMode)
            else
        {
            return nil
        }

        wisp = newWisp
        
        wisp.connectWithHandshake(certString: cert, sessionKey: wisp.sessionKey)
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("Error connecting with handshake: \(error)")
                self.handshakeDone = false
                self._error = error
                self._isViable = false
                self._state = .invalid
            }
            else
            {
                self.handshakeDone = true
                self._isViable = true
                self._state = .connected
            }
        }
    }

    func observeState(_ callback: @escaping (NWTCPConnectionState, Error?) -> Void) {
        self.stateCallback=callback
    }
    
    func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
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
    
    func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        readMinimumLength(length, maximumLength: length, completionHandler: completion)
    }
    
    func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Void)
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
    
    func writeClose()
    {
        _state = .disconnected
        _isViable = false
        network.writeClose()
    }
    
    func cancel()
    {
        _state = .cancelled
        _isViable = false
        network.cancel()
    }
}

extension Notification.Name
{
    static let wispConnectionState = Notification.Name("WispTCPConnectionState")
}
