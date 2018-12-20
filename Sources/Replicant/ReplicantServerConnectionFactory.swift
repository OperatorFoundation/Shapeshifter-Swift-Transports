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
    public var replicantConfig: ReplicantServerConfig
    
    public init(connection: Connection, replicantConfig: ReplicantServerConfig)
    {
        self.connection = connection
        self.replicantConfig = replicantConfig
    }
    
    public func connect() -> Connection?
    {
        if let currentConnection = connection
        {
            return ReplicantServerConnection(connection: currentConnection, using: .tcp, andReplicantConfig: replicantConfig)
        }
        
        return nil
    }
}
