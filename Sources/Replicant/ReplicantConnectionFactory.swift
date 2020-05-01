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

open class ReplicantConnectionFactory: ConnectionFactory
{
    public var name: String = "Replicant"
    
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var config: ReplicantConfig
    
    var logQueue = Queue<String>()
    
    public init?(ipString: String, portInt: UInt16, config: ReplicantConfig)
    {
        guard let port = NWEndpoint.Port(rawValue: portInt)
        else
        {
            print("Unable to initialize ReplicantConnectionFactory, a port could not be resolved from the provided UInt16: \(portInt)")
            return nil
        }
        
        self.host = NWEndpoint.Host(ipString)
        self.port = port
        self.config = config
    }
    
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
            return ReplicantConnection(connection: currentConnection, parameters: parameters, config: config, logQueue: logQueue)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
                else
            {
                print("Unable to connect, host or port is nil.\n\(host ?? "nil host")\n\(port?.debugDescription ?? "nil port")")
                return nil
            }
            
            return ReplicantConnection(host: currentHost, port: currentPort, parameters: parameters, config: config, logQueue: logQueue)
        }
    }
}
