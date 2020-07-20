//
//  ProteanConnectionFactory.swift
//  Protean
//
//  Created by Adelita Schule on 8/24/18.
//

import Foundation
import Logging
import Network
import Transport
import ProteanSwift

open class ProteanConnectionFactory: ConnectionFactory
{
    public var name: String = "Protean"
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var config: Protean.Config
    
    public let log: Logger
    
    public init?(hostString: String, portInt: UInt16, config: Protean.Config, logger: Logger)
    {
        guard let port = NWEndpoint.Port(rawValue: portInt)
            else { return nil }
        self.host = NWEndpoint.Host(hostString)
        self.port = port
        self.config = config
        self.log = logger
    }
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, config: Protean.Config, logger: Logger)
    {
        self.host = host
        self.port = port
        self.config = config
        self.log = logger
    }
    
    public init(connection: Connection, config: Protean.Config, logger: Logger)
    {
        self.connection = connection
        self.config = config
        self.log = logger
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return ProteanConnection(connection: currentConnection, config: config, using: parameters, logger: log)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
                else
            {
                return nil
            }
            
            return ProteanConnection(host: currentHost, port: currentPort, config: config, logger: log, using: parameters)
        }
    }
    
}
