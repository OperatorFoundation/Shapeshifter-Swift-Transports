//
//  TrackStrategy.swift
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

class TrackStrategy: Strategy
{
    var transports: [ConnectionFactory]
    var index = 0
    var trackDictionary = [String: Int]()
    // TODO: If we run out of transports to try because they have all failed just once start over
    
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
            if score == 1
            {
                return transport
            }
            else
            {
                transport = transports[index]
                score = findScore()
                incrementIndex()
            }
        }
        
        // If we've gotten this far, we've checked all but the transport we started with
        // We're back at the beginning, let's try that one now
        if findScore() == 1
        {
            return transports[index]
        }
        else
        {
            return nil
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
    
    func findScore() -> Int
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
