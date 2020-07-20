//
//  OptimizerConnectionFactory.swift
//  Optimizer
//
//  Created by Mafalda on 7/18/19.
//

import Foundation
import Logging
import Network
import Transport

open class OptimizerConnectionFactory: ConnectionFactory
{
    public var name: String = "Optimizer"
    public let log: Logger
    
    let currentStrategy: Strategy

    public init?(strategy: Strategy, logger: Logger)
    {
        self.currentStrategy = strategy
        self.log = logger
    }

    public func connect(using parameters: NWParameters) -> Connection?
    {
        var attemptCount = 0
        var connection: Connection?
        
        while connection == nil && attemptCount < 10
        {
            attemptCount += 1
            log.debug("\nOptimizer is attempting to connect.\nRound \(attemptCount)")
            
            guard let connectionFactory = currentStrategy.choose()
                else
            {
                continue
            }
            
            connection = OptimizerConnection(strategy: currentStrategy, connectionFactory: connectionFactory, logger: log, using: parameters)
        }
        
        return connection
    }
}
