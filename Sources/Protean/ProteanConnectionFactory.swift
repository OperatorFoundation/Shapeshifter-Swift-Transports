//
//  ProteanConnectionFactory.swift
//  Protean
//
//  Created by Adelita Schule on 8/24/18.
//

import Foundation
import Transport
import Network
import ProteanSwift

open class ProteanConnectionFactory: ConnectionFactory
{
    public var name: String = "Protean"
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var config: Protean.Config
    
    public init?(hostString: String, portInt: UInt16, config: Protean.Config)
    {
        guard let port = NWEndpoint.Port(rawValue: portInt)
            else { return nil }
        self.host = NWEndpoint.Host(hostString)
        self.port = port
        self.config = config
    }
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, config: Protean.Config)
    {
        self.host = host
        self.port = port
        self.config = config
    }
    
    public init(connection: Connection, config: Protean.Config)
    {
        self.connection = connection
        self.config = config
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return ProteanConnection(connection: currentConnection, config: config, using: parameters)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
                else
            {
                return nil
            }
            
            return ProteanConnection(host: currentHost, port: currentPort, config: config, using: parameters)
        }
    }
    
}
