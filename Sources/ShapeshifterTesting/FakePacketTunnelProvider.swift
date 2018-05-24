//
//  FakePacketTunnelProvider.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/30/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension
import Transport

open class FakePacketTunnelProvider: PacketTunnelProvider
{
    public init() {
        //        super.init()
    }
    
    open func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
    
    open func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    public func cancelTunnelWithError(_ error: Error?) {
        // Do nothing
    }

    public func createTCPConnectionThroughTunnel(to remoteEndpoint: NWEndpoint, enableTLS: Bool, tlsParameters TLSParameters: NWTLSParameters?, delegate: Any?) -> TCPConnection?
    {
        return FakeTCPConnection(to: remoteEndpoint)
    }
    
    public func createUDPSessionThroughTunnel(to remoteEndpoint: NWEndpoint,
                                                from localEndpoint: NWHostEndpoint?) -> NWUDPSession {
        return FakeUDPSession(to: remoteEndpoint, from: localEndpoint)
    }
    
    public func setTunnelNetworkSettings(_ tunnelNetworkSettings: NETunnelNetworkSettings?,
                                           completionHandler: ((Error?) -> Void)? = nil) {
        if let completion = completionHandler
        {
            completion(nil)
        }
    }
    
    open func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil)
    {
        if let completion = completionHandler
        {
            completion(nil)
        }
    }
}

