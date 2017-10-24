//
//  FakeTCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/24/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

class FakeTCPConnection: NWTCPConnection
{
    override var state: NWTCPConnectionState {
        get {
            return NWTCPConnectionState.connected
        }
    }
    
    override var isViable: Bool {
        get {
            return true
        }
    }
    
    override var error: Error? {
        get {
            return nil
        }
    }
    
    override var endpoint: NWEndpoint {
        get {
            return NWHostEndpoint(hostname: "8.8.8.8", port: "1234")
        }
    }
    
    override var remoteAddress: NWEndpoint? {
        get {
            return NWHostEndpoint(hostname: "8.8.8.8", port: "1234")
        }
    }
    
    override var localAddress: NWEndpoint? {
        get {
            return NWHostEndpoint(hostname: "127.0.0.1", port: "1234")
        }
    }
    
    override var connectedPath: NWPath? {
        get {
            return nil
        }
    }
    
    override var txtRecord: Data? {
        get {
            return nil
        }
    }
    
    override func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
    }
    
    override func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Void) {
    }
    
    override func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
        completion(nil)
    }
    
    override func writeClose()
    {
    }
    
    override func cancel() {
    }
    
    override var hasBetterPath: Bool {
        get {
            return false
        }
    }
    
    override init() {
        super.init()
    }
    
    override init(upgradeFor connection: NWTCPConnection) {
        super.init()
    }
}

func createFakeTCPConnection(to remoteEndpoint: NWEndpoint,
                             enableTLS: Bool,
                             tlsParameters TLSParameters: NWTLSParameters?,
                             delegate: Any?) -> NWTCPConnection
{
    return FakeTCPConnection()
}
