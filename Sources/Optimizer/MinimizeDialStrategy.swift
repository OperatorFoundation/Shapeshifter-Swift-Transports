//
//  MinimizeDialStrategy.swift
//  Optimizer
//
//  Created by Mafalda on 8/14/19.
//

import Foundation
import Transport

class MinimizeDialStrategy: Strategy
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
            if score == 0
            {
                return transport
            }
            else
            {
                incrementIndex(transports: transports)
                
                if let transportName = minDuration(), let minTransport = getTransport(named: transportName, fromTransports: transports)
                {
                    return minTransport
                }
                else
                {
                    transport = transports[index]
                    score = findScore(transports: transports)
                    continue
                }
                
            }
        }
        
        return transport
    }
    
    func report(transport: ConnectionFactory, successfulConnection: Bool, millisecondsToConnect: Int)
    {
        let threshhold = 60000
        
        if successfulConnection && millisecondsToConnect < threshhold
        {
            trackDictionary[transport.name] = millisecondsToConnect
        }
        else
        {
            trackDictionary[transport.name] = threshhold
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
            return 0
        }
    }
    
    func incrementIndex(transports:[ConnectionFactory])
    {
        index += 1
        
        if index >= transports.count
        {
            index = 0
        }
    }
    
    func minDuration() -> String?
    {
        var min = 61000
        var transport: String?
        
        for (key, value) in trackDictionary
        {
            if value < min
            {
                min = value
                transport = key
            }
        }

        return transport
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
    
    
}
