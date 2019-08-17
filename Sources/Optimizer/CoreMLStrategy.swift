//
//  CoreMLStrategy.swift
//  Optimizer
//
//  Created by Mafalda on 8/14/19.
//

import Foundation
import Transport

struct CoreMLStrategy: Strategy
{
    func choose(fromTransports transports: [ConnectionFactory]) -> ConnectionFactory?
    {
        return transports.first
    }
    
    func report(transport: ConnectionFactory, successfulConnection: Bool, millisecondsToConnect: Int) {
        //
    }
}
