//
//  FakeUDPSession.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/30/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

public class FakeUDPSession: NWUDPSession {
    var privEndpoint: NWEndpoint
    var privIsViable: Bool
    var privState: NWUDPSessionState

    override public var state: NWUDPSessionState {
        get {
            return privState
        }
    }
    
    override public var isViable: Bool {
        get {
            return privIsViable
        }
    }
    
    override public var endpoint: NWEndpoint {
        get {
            return privEndpoint
        }
    }
    
    init(to remoteEndpoint: NWEndpoint, from localEndpoint: NWHostEndpoint?) {
        self.privEndpoint = remoteEndpoint
        self.privState = .ready
        self.privIsViable = true
        
        super.init()
    }
}
