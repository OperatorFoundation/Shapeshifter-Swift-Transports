//
//  FakeTCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/24/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

public func createFakeTCPConnection(to:NWEndpoint,
                                    stateCallback:@escaping (NWTCPConnectionState, Error?) -> Void) -> FakeTCPConnection?
{
    return FakeTCPConnection(to: to, callback: stateCallback)
}

public class FakeTCPConnection: TCPConnection
{
    var network: URLSessionStreamTask
    var privEndpoint: NWEndpoint
    var privIsViable: Bool
    var privState: NWTCPConnectionState
    var stateCallback: (NWTCPConnectionState, Error?) -> Void
    
    public var state: NWTCPConnectionState {
        get {
            return privState
        }
    }
    
    public var isViable: Bool {
        get {
            return privIsViable
        }
    }
    
    public var error: Error? {
        get {
            return nil
        }
    }
    
    public var endpoint: NWEndpoint {
        get {
            return privEndpoint
        }
    }
    
    public var remoteAddress: NWEndpoint? {
        get {
            return privEndpoint
        }
    }
    
    public var localAddress: NWEndpoint? {
        get {
            return NWHostEndpoint(hostname: "127.0.0.1", port: "1234")
        }
    }
    
    public var connectedPath: NWPath? {
        get {
            return nil
        }
    }
    
    public var txtRecord: Data? {
        get {
            return nil
        }
    }
    
    public var hasBetterPath: Bool {
        get {
            return false
        }
    }

    init?(to: NWEndpoint, callback: @escaping (NWTCPConnectionState, Error?) -> Void)
    {
        if let hostendpoint = to as? NWHostEndpoint
        {
            privEndpoint = to
            let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
            network = session.streamTask(withHostName: "tcp://\(hostendpoint.hostname)", port: Int(hostendpoint.port)!)
            network.resume()
            
            privIsViable = true
            privState = .connected
            
            self.stateCallback = callback
            callback(privState, nil)
        }
        else
        {
            callback(.disconnected, TCPConnectionError.invalidNWEndpoint)
            return nil
        }
    }
    
    public func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        network.readData(ofMinLength: 0, maxLength: 100000, timeout: 60)
        {
            (data, bool, error) in
            
            guard error == nil else {
                completion(nil, error)
                return
            }
            
            guard data != nil else {
                completion(nil, nil)
                return
            }
            
            completion(data, nil)
        }
    }
    
    public func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Void) {
        readMinimumLength(length, maximumLength: length)
        {
            (data, error) in
            
            guard error == nil else {
                completion(nil, error)
                return
            }
            
            guard data != nil else {
                completion(nil, nil)
                return
            }
            
            completion(data, nil)
        }
    }
    
    public func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
        network.write(data, timeout: 0)
        {
            (error) in

            completion(error)
        }
    }
    
    public func writeClose()
    {
        network.closeWrite()
    }
    
    public func cancel() {
        writeClose()
        network.closeRead()
        privState = .cancelled
    }
}

