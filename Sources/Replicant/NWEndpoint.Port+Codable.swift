//
//  NWEndpoint.Port+Codable.swift
//  Replicant
//
//  Created by Mafalda on 1/29/19.
//

import Foundation
import Network

extension NWEndpoint.Port: Encodable
{
    public func encode(to encoder: Encoder) throws
    {
        let portInt = self.rawValue
        var container = encoder.singleValueContainer()
        
        do
        {
            try container.encode(portInt)
        }
        catch let error
        {
            throw error
        }
    }
}

extension NWEndpoint.Port: Decodable
{
    public init(from decoder: Decoder) throws
    {
        do
        {
            let container = try decoder.singleValueContainer()
            
            do
            {
                let portInt = try container.decode(UInt16.self)
                guard let port = NWEndpoint.Port(rawValue: portInt)
                    else
                {
                    throw ReplicantError.invalidPort
                }
                
                self = port
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

