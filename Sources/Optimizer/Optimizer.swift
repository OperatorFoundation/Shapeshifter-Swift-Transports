//
//  Optimizer.swift
//  Optimizer
//
//  Created by Mafalda on 7/12/19.
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
