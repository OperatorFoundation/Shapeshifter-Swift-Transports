//
//  MinimizeDialStrategy.swift
//  Optimizer
//
//  Created by Mafalda on 8/14/19.
//  MIT License
//
//  Copyright (c) 2020 Operator Foundation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Transport

class MinimizeDialStrategy: Strategy
{
    var transports: [ConnectionFactory]
    var index = 0
    var trackDictionary = [String: Int]()
    
    init(transports: [ConnectionFactory])
    {
        self.transports = transports
    }
    
    func choose() -> ConnectionFactory?
    {
        var transport = transports[index]
        var score = findScore()
        let startIndex = index
        
        incrementIndex()
        
        while startIndex != index
        {
            if score == 0
            {
                return transport
            }
            else
            {
                incrementIndex()
                
                if let transportName = minDuration(), let minTransport = getTransport(named: transportName, fromTransports: transports)
                {
                    return minTransport
                }
                else
                {
                    transport = transports[index]
                    score = findScore()
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
    
    func findScore() -> Int
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
    
    func incrementIndex()
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

    
}
