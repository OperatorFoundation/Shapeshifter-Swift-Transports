//
//  ProteanConnectionFactory.swift
//  Protean
//
//  Created by Adelita Schule on 8/24/18.
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
import Network
import Transport
import ProteanSwift

open class ProteanConnectionFactory: ConnectionFactory
{
    public var name: String = "Protean"
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var config: Protean.Config
    
    public let log: Logger
    
    public init?(hostString: String, portInt: UInt16, config: Protean.Config, logger: Logger)
    {
        guard let port = NWEndpoint.Port(rawValue: portInt)
            else { return nil }
        self.host = NWEndpoint.Host(hostString)
        self.port = port
        self.config = config
        self.log = logger
    }
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, config: Protean.Config, logger: Logger)
    {
        self.host = host
        self.port = port
        self.config = config
        self.log = logger
    }
    
    public init(connection: Connection, config: Protean.Config, logger: Logger)
    {
        self.connection = connection
        self.config = config
        self.log = logger
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return ProteanConnection(connection: currentConnection, config: config, using: parameters, logger: log)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
                else
            {
                return nil
            }
            
            return ProteanConnection(host: currentHost, port: currentPort, config: config, logger: log, using: parameters)
        }
    }
    
}
