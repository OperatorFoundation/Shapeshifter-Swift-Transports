//
//  FakeTCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/24/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension
import Transport

public func createFakeTCPConnection(to:NWEndpoint) -> FakeTCPConnection?
{
    return FakeTCPConnection(to: to)
}

public class FakeTCPConnection: TCPConnection
{    
    var network: URLSessionStreamTask
    var stateCallback: ((NWTCPConnectionState, Error?) -> Void)?
    
    private var _endpoint: NWEndpoint
    private var _isViable: Bool
    private var _state: NWTCPConnectionState {
        didSet {
            guard let callback = stateCallback else {
                return
            }
            
            callback(_state, nil)
        }
    }

    public var state: NWTCPConnectionState {
        get {
            return _state
        }
    }
    
    public var isViable: Bool {
        get {
            return _isViable
        }
    }
    
    public var error: Error? {
        get {
            return nil
        }
    }
    
    public var endpoint: NWEndpoint {
        get {
            return _endpoint
        }
    }
    
    public var remoteAddress: NWEndpoint? {
        get {
            return _endpoint
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

    init?(to: NWEndpoint)
    {
        if let hostendpoint = to as? NWHostEndpoint
        {
            _endpoint = to
            let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
            network = session.streamTask(withHostName: "\(hostendpoint.hostname)", port: Int(hostendpoint.port)!)
            network.resume()
            
            _isViable = true
            _state = .connected
        }
        else
        {
            return nil
        }
    }
    
    public func observeState(_ callback: @escaping (NWTCPConnectionState, Error?) -> Void) {
        self.stateCallback=callback
        
        callback(_state, nil)
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
        _state = .cancelled
    }
}

