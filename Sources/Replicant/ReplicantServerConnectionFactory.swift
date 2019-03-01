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
import SwiftQueue

open class ReplicantServerConnectionFactory
{
    public var connection: Connection?
    public var replicantConfig: ReplicantServerConfig
    var logQueue: Queue<String>
    
    public init(connection: Connection, replicantConfig: ReplicantServerConfig, logQueue: Queue<String>)
    {
        self.connection = connection
        self.replicantConfig = replicantConfig
        self.logQueue = logQueue
    }
    
    public func connect() -> Connection?
    {
        if let currentConnection = connection
        {
            return ReplicantServerConnection(connection: currentConnection, parameters: .tcp, replicantConfig: replicantConfig, logQueue: logQueue)
        }
        
        return nil
    }
}
