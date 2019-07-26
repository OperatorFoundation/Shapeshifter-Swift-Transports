//
//  ChooseRandom.swift
//  Optimizer
//
//  Created by Mafalda on 7/26/19.
//

import Foundation
import Transport

struct ChooseRandom: Strategy
{
    func choose(fromTransports transports: [ConnectionFactory]) -> ConnectionFactory?
    {
        return transports.randomElement()
    }
    
    func report(transport: ConnectionFactory, successfulConnection: Bool, millisecondsToConnect: Int)
    {
        
    }

}
