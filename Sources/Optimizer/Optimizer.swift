//
//  Optimizer.swift
//  Optimizer
//
//  Created by Mafalda on 7/12/19.
//

import Foundation
import Transport

/// OptimizerConnectionFactory will use strategy's Choose function in Connect to choose which transport connection to return
public protocol Strategy
{
    var transports: [ConnectionFactory] { get }
    
    func choose() -> ConnectionFactory?
    func report(transport: ConnectionFactory, successfulConnection: Bool, millisecondsToConnect: Int)
}

func getTransport(named name: String, fromTransports transports: [ConnectionFactory]) -> ConnectionFactory?
{
    for transport in transports
    {
        if transport.name == name
        {
            return transport
        }
    }
    
    return nil
}

func getIndex(ofTransport transport: ConnectionFactory, inTransports transports: [ConnectionFactory]) -> Int?
{
    for (index, thisTransport) in transports.enumerated()
    {
        if thisTransport.name == transport.name
        {
            return index
        }
    }

    return nil
}
