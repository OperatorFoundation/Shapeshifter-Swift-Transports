//
//  FakeTCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/24/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

public func createFakeTCPConnection(to:NWEndpoint) -> FakeTCPConnection {
    return FakeTCPConnection(to:to)!
}

public class FakeTCPConnection: NWTCPConnection
{
    var network: URLSessionStreamTask
    var privEndpoint: NWEndpoint
    var privIsViable: Bool
    var privState: NWTCPConnectionState
    
    override public var state: NWTCPConnectionState {
        get {
            return privState
        }
    }
    
    override public var isViable: Bool {
        get {
            return privIsViable
        }
    }
    
    override public var error: Error? {
        get {
            return nil
        }
    }
    
    override public var endpoint: NWEndpoint {
        get {
            return privEndpoint
        }
    }
    
    override public var remoteAddress: NWEndpoint? {
        get {
            return privEndpoint
        }
    }
    
    override public var localAddress: NWEndpoint? {
        get {
            return NWHostEndpoint(hostname: "127.0.0.1", port: "1234")
        }
    }
    
    override public var connectedPath: NWPath? {
        get {
            return nil
        }
    }
    
    override public var txtRecord: Data? {
        get {
            return nil
        }
    }
    
    override public var hasBetterPath: Bool {
        get {
            return false
        }
    }

    init?(to:NWEndpoint) {
        privEndpoint=to
        
        if let hostendpoint = to as? NWHostEndpoint
        {
            let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
            network = session.streamTask(withHostName: "tcp://\(hostendpoint.hostname)", port: Int(hostendpoint.port)!)
            network.resume()
            
            privIsViable=true
            privState = .connected
            
            super.init()
        } else {
            privIsViable=false
            privState = .disconnected
            return nil
        }
    }
    
    override public func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
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
    
    override public func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Void) {
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
    
    override public func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
        network.write(data, timeout: 0)
        {
            (error) in

            completion(error)
        }
    }
    
    override public func writeClose()
    {
        network.closeWrite()
    }
    
    override public func cancel() {
        writeClose()
        network.closeRead()
        privState = .cancelled
    }
}

