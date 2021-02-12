//
//  WispConnectionFactory.swift
//  Wisp
//
//  Created by Adelita Schule on 8/7/18.
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

#if os(Linux)
import NetworkLinux
#else
import Network
#endif

open class WispConnectionFactory: ConnectionFactory
{
    public var name: String = "Wisp"
    
    public var connection: NWConnection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var cert: String
    public var iatMode: Bool
    
    let log: Logger
    
    public convenience init?(hostString: String, portInt: UInt16, cert: String, iatMode: Bool, logger: Logger)
    {
        guard let port = NWEndpoint.Port(rawValue: portInt)
            else { return nil }
        
        self.init(host: NWEndpoint.Host(hostString), port: port, cert: cert, iatMode: iatMode, logger: logger)
    }
    
    public convenience init?(hostString: String, portInt: UInt16, config: WispConfig, logger: Logger)
    {
        guard let port = NWEndpoint.Port(rawValue: portInt)
            else { return nil }
        
        self.init(host: NWEndpoint.Host(hostString), port: port, cert: config.cert, iatMode: config.iatMode, logger: logger)
    }
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, cert: String, iatMode: Bool, logger: Logger)
    {
        self.host = host
        self.port = port
        self.cert = cert
        self.iatMode = iatMode
        self.log = logger
    }
    
    public func connect(using: NWParameters) -> Connection?
    {
        guard let currentHost = host, let currentPort = port
        else
        {
            return nil
        }
        
        return WispConnection(host: currentHost, port: currentPort, using: using, cert: cert, iatMode: iatMode, logger: log)
    }
    
}
