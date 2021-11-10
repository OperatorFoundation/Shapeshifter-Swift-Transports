//
//  OptimizerConnectionFactory.swift
//  Optimizer
//
//  Created by Mafalda on 7/18/19.
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
import Logging
import Transport

import Net

open class OptimizerConnectionFactory: ConnectionFactory
{
    public var name: String = "Optimizer"
    public let log: Logger
    
    let currentStrategy: Strategy

    public init?(strategy: Strategy, logger: Logger)
    {
        self.currentStrategy = strategy
        self.log = logger
    }

    public func connect(using parameters: NWParameters) -> Connection?
    {
        var attemptCount = 0
        var connection: Connection?
        
        while connection == nil && attemptCount < 10
        {
            attemptCount += 1
            log.debug("\nOptimizer is attempting to connect.\nRound \(attemptCount)")
            
            guard let connectionFactory = currentStrategy.choose()
                else
            {
                continue
            }
            
            connection = OptimizerConnection(strategy: currentStrategy, connectionFactory: connectionFactory, logger: log, using: parameters)
        }
        
        return connection
    }
}
