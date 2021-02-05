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
