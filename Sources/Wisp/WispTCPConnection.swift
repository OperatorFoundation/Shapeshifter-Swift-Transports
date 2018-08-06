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
import Transport

let certKey = "cert"
let iatKey = "iatMode"


public func createWispTCPConnection(connection: Connection,
                                    host: NWEndpoint.Host,
                                    port: NWEndpoint.Port,
                                    using parameters: NWParameters,
                                    cert: String,
                                    iatMode: Bool) -> WispTCPConnection?
{
    return WispTCPConnection(connection: connection, host: host, port: port, using: parameters, cert: cert, iatMode: iatMode)
}

public class WispTCPConnection: NWConnection
{
    /// Use this to create connections
    var connectionFactory: NetworkConnectionFactory?
    var wispConnection: Connection
    
    //var network: Connection
    var writeClosed = false
    var wisp: WispProtocol
    var handshakeDone = false
    
    //public var state: NWConnectionState
    public var isViable: Bool
    public var error: Error?
    
    public var endpoint: NWEndpoint?
    public var remoteAddress: NWEndpoint?
    public var localAddress: NWEndpoint?
    //public var connectedPath: NWPath?
    public var txtRecord: Data?
    public var hasBetterPath = false
    
    public init?(connection: Connection,
                 host: NWEndpoint.Host,
                 port: NWEndpoint.Port,
                 using parameters: NWParameters,
                 cert: String,
                 iatMode: Bool)
    {
//        network = connection
        wispConnection = connection
        isViable = false
//        _state = .connecting
       
        
        guard let newWisp = WispProtocol(connection: connection, cert: cert, iatMode: iatMode)
            else
        {
            return nil
        }

        wisp = newWisp
        super.init(host: host, port: port, using: parameters)
        wisp.connectWithHandshake(certString: cert, sessionKey: wisp.sessionKey)
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("Error connecting with handshake: \(error)")
                self.handshakeDone = false
                self.error = error
                self.isViable = false
//                self._state = .invalid
            }
            else
            {
                self.handshakeDone = true
                self.isViable = true
//                self._state = .connected
            }
        }
    }
//
//    public func observeState(_ callback: @escaping (NWTCPConnectionState, Error?) -> Void) {
//        self.stateCallback=callback
//    }
    
    public func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
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
    
    public func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        readMinimumLength(length, maximumLength: length, completionHandler: completion)
    }
    
    public func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
        guard let frame = wisp.encoder?.encode(payload: data)
        else
        {
            print("Failed to encoded data while attempting to WispTCPConnection write.")
            completion(nil)
            return
        }
        let context = NWConnection.ContentContext()
        let sendCompletion = NWConnection.SendCompletion(completion:
        {
            (error) in
            
            completion(error)
        })
        
        wispConnection.send(content: frame, contentContext: context, isComplete: true, completion: sendCompletion)
//
//        network.write(frame, timeout: 0)
//        {
//            (error) in
//
//            completion(error)
//        }
    }
    
//    public func writeClose()
//    {
//        _state = .disconnected
//        _isViable = false
//        network.writeClose()
//    }
//
//    public func cancel()
//    {
//        _state = .cancelled
//        _isViable = false
//        network.cancel()
//    }
        
}

public extension Notification.Name
{
    static let wispConnectionState = Notification.Name("WispTCPConnectionState")
}
