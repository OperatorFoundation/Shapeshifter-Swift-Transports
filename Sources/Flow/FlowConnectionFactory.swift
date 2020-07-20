//
//  FlowConnectionFactory.swift
//  Flow
//
//  Created by Dr. Brandon Wiley on 11/1/18.
//

import Foundation
import Logging
import Network
import Flower
import Transport

open class FlowConnectionFactory: ConnectionFactory
{
    public var name: String = "Flow"
    
    let flower: FlowerController
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
    let log: Logger
    
    init(flower: FlowerController, host: NWEndpoint.Host, port: NWEndpoint.Port, logger: Logger)
    {
        self.flower = flower
        self.host = host
        self.port = port
        self.log = logger
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        return FlowConnection(flower: flower, host: host, port: port, using: parameters, logger: log)
    }
}
