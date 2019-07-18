//
//  OptimizerConnectionFactory.swift
//  Optimizer
//
//  Created by Mafalda on 7/18/19.
//

import Foundation
import Transport
import Network

open class OptimizerConnectionFactory: ConnectionFactory, Strategy
{
    var currentConnectionFactory: ConnectionFactory?
    var currentConnectionParameters: NWParameters = .tcp
    
    public init?(possibleTransports transports: [ConnectionFactory])
    {
        if let connectionFactory = chooseFirst(fromTransports: transports)
        {
            self.currentConnectionFactory = connectionFactory
        }
        else
        {
            return nil
        }
    }
    
    public func choose(fromTransports transports: [ConnectionFactory]) -> ConnectionFactory?
    {
        return chooseFirst(fromTransports: transports)
    }
    
    func chooseFirst(fromTransports transports: [ConnectionFactory]) -> ConnectionFactory?
    {
        return transports.first
    }
    
    func chooseRandom(fromTransports transports: [ConnectionFactory]) -> ConnectionFactory?
    {
        return transports.randomElement()
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        guard let connectionFactory = currentConnectionFactory
            else { return nil }
        
        return connectionFactory.connect(using: currentConnectionParameters)
    }
    
    
}
