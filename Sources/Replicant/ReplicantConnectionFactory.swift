//
//  ReplicantConnectionFactory.swift
//  Replicant
//
//  Created by Adelita Schule on 11/21/18.
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
import Network
import ReplicantSwift
import Logging
import SwiftQueue

open class ReplicantConnectionFactory: ConnectionFactory
{
    public var name: String = "Replicant"
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var config: ReplicantConfig<SilverClientConfig>
    
    let log: Logger
        
    public init?(ipString: String, portInt: UInt16, config: ReplicantConfig<SilverClientConfig>, logger: Logger)
    {
        guard let port = NWEndpoint.Port(rawValue: portInt)
        else
        {
            logger.error("Unable to initialize ReplicantConnectionFactory, a port could not be resolved from the provided UInt16: \(portInt)")
            return nil
        }
        
        self.host = NWEndpoint.Host(ipString)
        self.port = port
        self.config = config
        self.log = logger
    }

    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, config: ReplicantConfig<SilverClientConfig>, log: Logger)
    {
        self.host = host
        self.port = port
        self.config = config
        self.log = log
    }

    public init(connection: Connection, config: ReplicantConfig<SilverClientConfig>, log: Logger)
    {
        self.connection = connection
        self.config = config
        self.log = log
    }
    
    public func connect(using parameters: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return ReplicantConnection(connection: currentConnection, parameters: parameters, config: config, logger: log)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
                else
            {
                log.error("Unable to connect, host or port is nil.\n\(host ?? "nil host")\n\(port?.debugDescription ?? "nil port")")
                return nil
            }
            
            return ReplicantConnection(host: currentHost, port: currentPort, parameters: parameters, config: config, logger: log)
        }
    }
}
