//
//  ReplicantServerConnectionFactory.swift
//  Replicant
//
//  Created by Adelita Schule on 12/11/18.
//

import Foundation
import Logging
import Transport
import Network
import ReplicantSwift
import SwiftQueue

open class ReplicantServerConnectionFactory
{
    public let log: Logger
    public var connection: Connection?
    public var replicantConfig: ReplicantServerConfig
        
    public init(connection: Connection, replicantConfig: ReplicantServerConfig, logger: Logger)
    {
        self.connection = connection
        self.replicantConfig = replicantConfig
        self.log = logger
    }
    
    public func connect() -> Connection?
    {
        if let currentConnection = connection
        {
            return ReplicantServerConnection(connection: currentConnection, parameters: .tcp, replicantConfig: replicantConfig, logger: log)
        }
        
        return nil
    }
}
