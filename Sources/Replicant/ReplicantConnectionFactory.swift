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
import Logging
import SwiftQueue

open class ReplicantConnectionFactory: ConnectionFactory
{
    public var name: String = "Replicant"
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var config: ReplicantConfig<SilverClientConfig>
    
    let log: Logger
        
    public init?(ipString: String, portInt: UInt16, config: ReplicantConfig<SilverClientConfig>, logger: Logger)
    {
        guard let port = NWEndpoint.Port(rawValue: portInt)
        else
        {
            logger.error("Unable to initialize ReplicantConnectionFactory, a port could not be resolved from the provided UInt16: \(portInt)")
            return nil
        }
        
        self.host = NWEndpoint.Host(ipString)
        self.port = port
        self.config = config
        self.log = logger
    }

    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, config: ReplicantConfig<SilverClientConfig>, log: Logger)
    {
        self.host = host
        self.port = port
        self.config = config
        self.log = log
    }

    public init(connection: Connection, config: ReplicantConfig<SilverClientConfig>, log: Logger)
    {
        self.connection = connection
        self.config = config
        self.log = log
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return ReplicantConnection(connection: currentConnection, parameters: parameters, config: config, logger: log)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
                else
            {
                log.error("Unable to connect, host or port is nil.\n\(host ?? "nil host")\n\(port?.debugDescription ?? "nil port")")
                return nil
            }
            
            return ReplicantConnection(host: currentHost, port: currentPort, parameters: parameters, config: config, logger: log)
        }
    }
}
