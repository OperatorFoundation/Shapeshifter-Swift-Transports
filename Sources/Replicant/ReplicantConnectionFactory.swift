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
import SwiftQueue

open class ReplicantConnectionFactory
{
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var config: ReplicantConfig
    
    var logQueue: Queue<String>
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, config: ReplicantConfig, logQueue: Queue<String>)
    {
        self.host = host
        self.port = port
        self.config = config
        self.logQueue = logQueue
    }
    
    public init(connection: Connection, config: ReplicantConfig, logQueue: Queue<String>)
    {
        self.connection = connection
        self.config = config
        self.logQueue = logQueue
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return ReplicantConnection(connection: currentConnection, parameters: parameters, config: config, logQueue: logQueue)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
                else
            {
                return nil
            }
            
            return ReplicantConnection(host: currentHost, port: currentPort, parameters: parameters, config: config, logQueue: logQueue)
        }
    }
}
