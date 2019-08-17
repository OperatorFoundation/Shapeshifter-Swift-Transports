//
//  RotateStrategy.swift
//  Optimizer
//
//  Created by Mafalda on 8/14/19.
//

import Foundation
import Transport

class RotateStrategy: Strategy
{
    var index: Int = 0
    
    func choose(fromTransports transports: [ConnectionFactory]) -> ConnectionFactory?
    {
        let transport = transports[index]
        index += 1
        
        if index >= transports.count
        {
            index = 0
        }
        
        return transport
    }
    
    func report(transport: ConnectionFactory, successfulConnection: Bool, millisecondsToConnect: Int) {
        //
    }
    
    
}
