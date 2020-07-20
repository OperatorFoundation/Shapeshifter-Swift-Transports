//
//  PassthroughConnectionFactory.swift
//  Wisp
//
//  Created by Adelita Schule on 8/10/18.
//

import Foundation
import Logging
import Network
import Transport

open class PassthroughConnectionFactory: ConnectionFactory
{
    public var name: String = "Passthrough"
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    
    let log: Logger
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, logger: Logger)
    {
        self.host = host
        self.port = port
        self.log = logger
    }
    
    public init(connection: Connection, logger: Logger)
    {
        self.connection = connection
        self.log = logger
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return PassthroughConnection(connection: currentConnection, using: parameters, logger: log)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
                else
            {
                return nil
            }
            
            return PassthroughConnection(host: currentHost, port: currentPort, using: parameters, logger: log)
        }
        
    }
}
