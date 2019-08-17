//
//  TrackStrategy.swift
//  Optimizer
//
//  Created by Mafalda on 8/14/19.
//

import Foundation
import Transport

class TrackStrategy: Strategy
{
    var index = 0
    var trackDictionary = [String: Int]()
    
    func choose(fromTransports transports: [ConnectionFactory]) -> ConnectionFactory?
    {
        var transport = transports[index]
        var score = findScore(transports: transports)
        let startIndex = index
        
        incrementIndex(transports: transports)
        
        while startIndex != index
        {
            if score == 1
            {
                return transport
            }
            else
            {
                transport = transports[index]
                score = findScore(transports: transports)
                incrementIndex(transports: transports)
            }
        }
        
        return nil
    }
    
    func incrementIndex(transports: [ConnectionFactory])
    {
        index += 1
        
        if index >= transports.count
        {
            index = 0
        }
    }
    
    func findScore(transports: [ConnectionFactory]) -> Int
    {
        let transport = transports[index]
        if let score = trackDictionary[transport.name]
        {
            return score
        }
        else
        {
            return 1
        }
    }
    
    func report(transport: ConnectionFactory, successfulConnection: Bool, millisecondsToConnect: Int)
    {
        if successfulConnection
        {
            trackDictionary[transport.name] = 1
        }
        else
        {
            trackDictionary[transport.name] = 0
        }
    }
}
