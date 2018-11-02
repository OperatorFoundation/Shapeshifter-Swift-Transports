//
//  FlowConnectionFactory.swift
//  Flow
//
//  Created by Dr. Brandon Wiley on 11/1/18.
//

import Foundation
import Transport
import Network
import Flower

open class FlowConnectionFactory
{
    let flower: FlowerController
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
    
    init(flower: FlowerController, host: NWEndpoint.Host, port: NWEndpoint.Port)
    {
        self.flower = flower
        self.host = host
        self.port = port
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        return FlowConnection(flower: flower, host: host, port: port, using: parameters)
    }
}
