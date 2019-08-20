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
    var transports: [ConnectionFactory]
    var index: Int = 0
    
    init(transports: [ConnectionFactory])
    {
        self.transports = transports
    }
    
    func choose() -> ConnectionFactory?
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
