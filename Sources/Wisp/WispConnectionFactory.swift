//
//  WispConnectionFactory.swift
//  Wisp
//
//  Created by Adelita Schule on 8/7/18.
//

import Foundation
import Transport
import Network

open class WispConnectionFactory: ConnectionFactory
{
    public var connection: Connection?
    public var host: NWEndpoint.Host?
    public var port: NWEndpoint.Port?
    public var cert: String
    public var iatMode: Bool
    
    
    public init(host: NWEndpoint.Host, port: NWEndpoint.Port, cert: String, iatMode: Bool)
    {
        self.host=host
        self.port=port
        self.cert = cert
        self.iatMode = iatMode
    }
    
    public init(connection: Connection, cert: String, iatMode: Bool)
    {
        self.connection = connection
        self.cert = cert
        self.iatMode = iatMode
    }
    
    public func connect(_ using: NWParameters) -> Connection?
    {
        if let currentConnection = connection
        {
            return WispConnection(connection: currentConnection, using: using, cert: cert, iatMode: iatMode)
        }
        else
        {
            guard let currentHost = host, let currentPort = port
            else
            {
                return nil
            }
            
            return WispConnection(host: currentHost, port: currentPort, using: using, cert: cert, iatMode: iatMode)
        }

    }
    
}
