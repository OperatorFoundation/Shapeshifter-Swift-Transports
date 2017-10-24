//
//  Rot13TCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/22/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

func createRot13TCPConnection(provider: NEPacketTunnelProvider, to: NWEndpoint, key: Int) -> Rot13TCPConnection {
    return Rot13TCPConnection(provider: provider, to: to, key: key)
}

func createRot13TCPConnection(connection: NWTCPConnection, key: Int) -> Rot13TCPConnection {
    return Rot13TCPConnection(connection: connection, key: key)
}

class Rot13TCPConnection: NWTCPConnection {
    var rotkey: Int
    var network: NWTCPConnection
    
    init(provider: NEPacketTunnelProvider, to: NWEndpoint, key: Int) {
        rotkey = key
        network = provider.createTCPConnectionThroughTunnel(to: to, enableTLS: false, tlsParameters: nil, delegate: nil)

        super.init()
    }

    init(connection: NWTCPConnection, key: Int) {
        rotkey = key
        network = connection
        
        super.init()
    }
    
//    init(upgradeFor connection: NWTCPConnection)
    
    override func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void) {
        network.readMinimumLength(minimum, maximumLength: maximum) {
            (data, error) in

            guard error == nil else {
                completion(nil, error)
                return
            }

            guard data != nil else {
                completion(nil, nil)
                return
            }
            
            let decoded = self.decode(data!)
            
            completion(decoded, nil)
        }
    }
    
    override func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Void) {
        network.readLength(length) {
            (data, error) in
            
            guard error == nil else {
                completion(nil, error)
                return
            }
            
            guard data != nil else {
                completion(nil, nil)
                return
            }
            
            let decoded = self.decode(data!)
            
            completion(decoded, nil)
        }
    }
    
    override func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Void) {
        let encoded = encode(data)!
        network.write(encoded) {
            (error) in

            completion(error)
        }
    }
    
    override func writeClose() {
        network.writeClose()
    }
    
    override func cancel() {
        network.cancel()
    }
    
    func encode(_ data: Data) -> Data? {
        return transform(data, key: rotkey)
    }
    
    func decode(_ data: Data) -> Data? {
        return transform(data, key: -rotkey)
    }
    
    func transform(_ data: Data, key: Int) -> Data {
        var mutdata = data
        mutdata.withUnsafeMutableBytes {
            (bytePtr: UnsafeMutablePointer<UInt8>) in
            
            let byteBuffer = UnsafeMutableBufferPointer(start: bytePtr, count: data.count/MemoryLayout<Int8>.stride)
            
            for index in 1...byteBuffer.count {
                byteBuffer[index]=UInt8(byteBuffer[index])+UInt8(key)
            }
        }
        
        return mutdata
    }
}
