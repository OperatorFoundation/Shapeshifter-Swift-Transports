//
//  File.swift
//  
//
//  Created by Mafalda on 2/4/21.
//

import Foundation

public struct WispConfig: Codable
{
    public let cert: String
    public let iatMode: Bool
    
    private enum CodingKeys : String, CodingKey
    {
        case cert, iatMode = "iat-mode"
    }
    
    public init(cert: String, iatMode: Bool)
    {
        self.cert = cert
        self.iatMode = iatMode
    }
    
    init?(from data: Data)
    {
        let decoder = JSONDecoder()
        do
        {
            let decoded = try decoder.decode(WispConfig.self, from: data)
            self = decoded
        }
        catch let decodeError
        {
            print("Error decoding Wisp Config data: \(decodeError)")
            return nil
        }
    }
    
    public init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        iatMode = try container.decode(Bool.self, forKey: .iatMode, transformFrom: Int.self)
        cert = try container.decode(String.self, forKey: .cert)
    }
    
    public init?(path: String)
    {
        let url = URL(fileURLWithPath: path)
        
        do
        {
            let data = try Data(contentsOf: url)
            self.init(from: data)
        }
        catch (let error)
        {
            print("Failed to get data from path \(url.path). \nError: \(error)")
            return nil
        }
    }
}

extension KeyedDecodingContainer
{
    
    func decodeIfPresent(_ type: Bool.Type, forKey key: K, transformFrom: Int.Type) throws -> Bool?
    {
        guard let value = try decodeIfPresent(transformFrom, forKey: key)
        else { return nil }
        return value != 0
    }
    
    func decode(_ type: Bool.Type, forKey key: K, transformFrom: Int.Type) throws -> Bool
    {
        guard let int = try? decode(transformFrom, forKey: key)
        else
        {
            throw DecodingError.typeMismatch(Int.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Decoding of \(type) from \(transformFrom) failed"))
        }
        
        return int != 0
    }
}
