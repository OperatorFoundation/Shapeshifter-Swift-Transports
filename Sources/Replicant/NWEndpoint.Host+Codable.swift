//
//  NWEnpoint.Host+Codable.swift
//  Replicant
//
//  Created by Mafalda on 1/29/19.
//

import Foundation
import Network

extension NWEndpoint.Host: Encodable
{
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.singleValueContainer()
        
        switch self
        {
        case .ipv4(let ipv4Address):
            do
            {
                let addressString = "\(ipv4Address)"
                try container.encode(addressString)
            }
            catch let error
            {
                throw error
            }
        case .ipv6(let ipv6Address):
            do
            {
                let addressString = "\(ipv6Address)"
                try container.encode(addressString)
            }
            catch let error
            {
                throw error
            }
        case .name(let nameString, _):
            do
            {
                try container.encode(nameString)
            }
            catch let error
            {
                throw error
            }
        default:
            throw HostError.invalidIP
        }
    }
}

enum HostError: Error
{
    case invalidIP
}

extension NWEndpoint.Host: Decodable
{
    public init(from decoder: Decoder) throws
    {
        do
        {
            let container = try decoder.singleValueContainer()
            
            do
            {
                let addressString = try container.decode(String.self)
                self.init(addressString)
            }
            catch let error
            {
                throw error
            }
        }
        catch let error
        {
            throw error
        }
    }
}
