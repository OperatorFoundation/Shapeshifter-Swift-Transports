//
//  FakeNEPacketTunnelProvider.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/30/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

extension NEPacketTunnelProvider: PacketTunnelProvider {
}

class FakeNEPacketTunnelProvider: NEPacketTunnelProvider
{
    override var appRules: [NEAppRule]? {
        get {
            return nil
        }
    }
    override var packetFlow: NEPacketTunnelFlow {
        get {
            return NEPacketTunnelFlow()
        }
    }

    override var protocolConfiguration: NEVPNProtocol {
        get {
            return NEVPNProtocol()
        }
    }
    
    override var routingMethod: NETunnelProviderRoutingMethod {
        get {
            return NETunnelProviderRoutingMethod.destinationIP
        }
    }
    
    override var reasserting: Bool {
        get {
            return false
        }
        
        set {
            // Ignore set value
        }
    }
    
    override init() {
//        super.init()
    }

    override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    override func cancelTunnelWithError(_ error: Error?) {
        // Do nothing
    }
    
    override func createTCPConnectionThroughTunnel(to remoteEndpoint: NWEndpoint,
                                          enableTLS: Bool,
                                          tlsParameters TLSParameters: NWTLSParameters?,
                                          delegate: Any?) -> NWTCPConnection {
        return FakeTCPConnection(to: remoteEndpoint)!
    }
    
    override func createUDPSessionThroughTunnel(to remoteEndpoint: NWEndpoint,
                                       from localEndpoint: NWHostEndpoint?) -> NWUDPSession {
        return FakeUDPSession(to: remoteEndpoint, from: localEndpoint)
    }
    
    override func setTunnelNetworkSettings(_ tunnelNetworkSettings: NETunnelNetworkSettings?,
                                  completionHandler: ((Error?) -> Void)? = nil) {
        if let completion = completionHandler
        {
            completion(nil)
        }
    }
    
    override func handleAppMessage(_ messageData: Data,
                          completionHandler: ((Data?) -> Void)? = nil)
    {
        if let completion = completionHandler
        {
            completion(nil)
        }
    }
}
