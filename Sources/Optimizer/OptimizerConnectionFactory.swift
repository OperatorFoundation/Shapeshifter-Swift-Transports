//
//  OptimizerConnectionFactory.swift
//  Optimizer
//
//  Created by Mafalda on 7/18/19.
//

import Foundation
import Transport
import Network

open class OptimizerConnectionFactory: ConnectionFactory
{
    public var name: String = "Optimizer"
    let currentStrategy: Strategy
    
    public init?(strategy: Strategy)
    {
        self.currentStrategy = strategy
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        var attemptCount = 0
        var connection: Connection?
        
        while connection == nil && attemptCount < 10
        {
            attemptCount += 1
            print("\nOptimizer is attempting to connect.\nRound \(attemptCount)")
            
            guard let connectionFactory = currentStrategy.choose()
                else
            {
                continue
            }
            
            let preConnectionDate = Date()
            connection = connectionFactory.connect(using: parameters)
            let postConnectionDate = Date()
            
            // If we don't have a connection yet, report it
            if connection == nil
            {
                let connectTime = postConnectionDate.timeIntervalSince(preConnectionDate)
                currentStrategy.report(transport: connectionFactory, successfulConnection: false, millisecondsToConnect: Int(connectTime*1000))
            }
            else
            {
                let connectTime = postConnectionDate.timeIntervalSince(preConnectionDate)
                currentStrategy.report(transport: connectionFactory, successfulConnection: true, millisecondsToConnect: Int(connectTime*1000))
            }
        }
        
        return connection
    }
}
