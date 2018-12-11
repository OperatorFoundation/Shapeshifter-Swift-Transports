//
//  ReplicantServerConnectionFactory.swift
//  Replicant
//
//  Created by Adelita Schule on 12/11/18.
//

import Foundation
import Transport
import Network
import ReplicantSwift

open class ReplicantServerConnectionFactory
{
    public var connection: Connection?
    public var port: NWEndpoint.Port?
    public var config: ReplicantServerConfig
    
    public init(port: NWEndpoint.Port, config: ReplicantServerConfig)
    {
        self.port = port
        self.config = config
    }
    
    public init(connection: Connection, config: ReplicantServerConfig)
    {
        self.connection = connection
        self.config = config
    }
    
    //FIXME: Handle case with no current connection
    public func connect(using parameters: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return ReplicantServerConnection(connection: currentConnection, using: parameters, and: config)
        }
//        else
//        {
//            guard let currentPort = port
//                else
//            {
//                return nil
//            }
//
//            return ReplicantConnection(host: currentHost, port: currentPort, using: parameters, and: config)
//        }
        
        return nil
    }
}
