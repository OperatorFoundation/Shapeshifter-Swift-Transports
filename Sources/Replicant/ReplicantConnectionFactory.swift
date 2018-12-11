//
//  ReplicantConnectionFactory.swift
//  Replicant
//
//  Created by Adelita Schule on 11/21/18.
//

import Foundation
import Transport
import Network
import ReplicantSwift

open class ReplicantConnectionFactory
{
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var config: ReplicantConfig
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, config: ReplicantConfig)
    {
        self.host = host
        self.port = port
        self.config = config
    }
    
    public init(connection: Connection, config: ReplicantConfig)
    {
        self.connection = connection
        self.config = config
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return ReplicantConnection(connection: currentConnection, using: parameters, and: config)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
                else
            {
                return nil
            }
            
            return ReplicantConnection(host: currentHost, port: currentPort, using: parameters, and: config)
        }
    }
}