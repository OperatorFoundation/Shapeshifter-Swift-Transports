//
//  File.swift
//  Shapeshifter-Swift-TransportsPackageDescription
//
//  Created by Adelita Schule on 12/19/18.
//

import Foundation
import Network

public struct ServerConfig: Codable
{
    public let ipString: String?
    public let portInt: NWEndpoint.Port
}

extension String
{
    var host: NWEndpoint.Host?
    {
        return NWEndpoint.Host(self)
    }
}

extension NWEndpoint.Port: Codable
{

}
