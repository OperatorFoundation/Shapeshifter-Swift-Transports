//
//  FakePacketTunnelProvider.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/30/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

class FakePacketTunnelProvider: PacketTunnelProvider
{
    init() {
        //        super.init()
    }
    
    func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
    
    func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    func cancelTunnelWithError(_ error: Error?) {
        // Do nothing
    }
    
    func createTCPConnectionThroughTunnel(to remoteEndpoint: NWEndpoint,
                                                   enableTLS: Bool,
                                                   tlsParameters TLSParameters: NWTLSParameters?,
                                                   delegate: Any?) -> NWTCPConnection {
        return FakeTCPConnection(to: remoteEndpoint)!
    }
    
    func createUDPSessionThroughTunnel(to remoteEndpoint: NWEndpoint,
                                                from localEndpoint: NWHostEndpoint?) -> NWUDPSession {
        return FakeUDPSession(to: remoteEndpoint, from: localEndpoint)
    }
    
    func setTunnelNetworkSettings(_ tunnelNetworkSettings: NETunnelNetworkSettings?,
                                           completionHandler: ((Error?) -> Void)? = nil) {
        if let completion = completionHandler
        {
            completion(nil)
        }
    }
    
    func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil)
    {
        if let completion = completionHandler
        {
            completion(nil)
        }
    }
}

