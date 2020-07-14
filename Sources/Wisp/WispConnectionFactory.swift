//
//  WispConnectionFactory.swift
//  Wisp
//
//  Created by Adelita Schule on 8/7/18.
//

import Foundation
import Logging
import Transport
import Network

open class WispConnectionFactory: ConnectionFactory
{
    public var name: String = "Wisp"
    
    public var connection: NWConnection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var cert: String
    public var iatMode: Bool
    
    let log: Logger
    
    public init?(hostString: String, portInt: UInt16, cert: String, iatMode: Bool, logger: Logger)
    {
        guard let port = NWEndpoint.Port(rawValue: portInt)
            else { return nil }
        self.host = NWEndpoint.Host(hostString)
        self.port = port
        self.cert = cert
        self.iatMode = iatMode
        self.log = logger
    }
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, cert: String, iatMode: Bool, logger: Logger)
    {
        self.host = host
        self.port = port
        self.cert = cert
        self.iatMode = iatMode
        self.log = logger
    }
    
    public init(connection: NWConnection, cert: String, iatMode: Bool, logger: Logger)
    {
        self.connection = connection
        self.cert = cert
        self.iatMode = iatMode
        self.log = logger
    }
    
    public func connect(using: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return WispConnection(connection: currentConnection, using: using, cert: cert, iatMode: iatMode, logger: log)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
            else
            {
                return nil
            }
            
            return WispConnection(host: currentHost, port: currentPort, using: using, cert: cert, iatMode: iatMode, logger: log)
        }

    }
    
}
