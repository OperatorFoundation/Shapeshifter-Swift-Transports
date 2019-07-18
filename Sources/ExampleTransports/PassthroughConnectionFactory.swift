//
//  PassthroughConnectionFactory.swift
//  Wisp
//
//  Created by Adelita Schule on 8/10/18.
//

import Foundation
import Transport
import Network

open class PassthroughConnectionFactory: ConnectionFactory
{
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port)
    {
        self.host = host
        self.port = port
    }
    
    public init(connection: Connection)
    {
        self.connection = connection
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return PassthroughConnection(connection: currentConnection, using: parameters)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
                else
            {
                return nil
            }
            
            return PassthroughConnection(host: currentHost, port: currentPort, using: parameters)
        }
        
    }
}
