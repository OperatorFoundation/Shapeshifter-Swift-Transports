//
//  PacketTunnelProvider.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 11/9/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

public protocol PacketTunnelProvider {
    func createTCPConnectionThroughTunnel(to remoteEndpoint: NWEndpoint,
                                          enableTLS: Bool,
                                          tlsParameters TLSParameters: NWTLSParameters?,
                                          delegate: Any?) -> NWTCPConnection
}
