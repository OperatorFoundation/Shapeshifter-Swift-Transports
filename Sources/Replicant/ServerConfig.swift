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
    public let host: NWEndpoint.Host?
    public let port: NWEndpoint.Port
    
    public init(withPort port: NWEndpoint.Port, andHost host: NWEndpoint.Host?)
    {
        self.port = port
        self.host = host
    }
    
    /// Creates and returns a JSON representation of the ServerConfig struct.
    public func createJSON() -> Data?
    {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do
        {
            let serverConfigData = try encoder.encode(self)
            return serverConfigData
        }
        catch (let error)
        {
            print("Failed to encode Server config into JSON format: \(error)")
            return nil
        }
    }
    
    /// Checks for a valid JSON at the provided path and attempts to decode it into a server configuration file. Returns a ServerConfig struct if it is successful
    /// - Parameters:
    ///     - path: The complete path where the config file is located.
    /// - Returns: The ReplicantServerConfig struct that was decoded from the JSON file located at the provided path, or nil if the file was invalid or missing.
    static public func parseJSON(atPath path: String) -> ServerConfig?
    {
        let filemanager = FileManager()
        let decoder = JSONDecoder()
        
        guard let jsonData = filemanager.contents(atPath: path)
            else
        {
            print("\nUnable to get JSON data at path: \(path)\n")
            return nil
        }
        
        do
        {
            let config = try decoder.decode(ServerConfig.self, from: jsonData)
            return config
        }
        catch (let error)
        {
            print("\nUnable to decode JSON into ServerConfig: \(error)\n")
            return nil
        }
    }
}

extension String
{
    var host: NWEndpoint.Host?
    {
        return NWEndpoint.Host(self)
    }
}
