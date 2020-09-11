//
//  File.swift
//  Shapeshifter-Swift-TransportsPackageDescription
//
//  Created by Adelita Schule on 12/19/18.
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
import Datable
import Song
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Network
#elseif os(Linux)
import NetworkLinux
#endif


public struct ServerConfig: Codable, Equatable
{
    public let host: NWEndpoint.Host?
    public let port: NWEndpoint.Port
    
    public init(withPort port: NWEndpoint.Port, andHost host: NWEndpoint.Host?)
    {
        self.port = port
        self.host = host
    }
    
    public init?(data: Data)
    {
        let decoder = SongDecoder()

        do
        {
            let decoded = try decoder.decode(ServerConfig.self, from: data)
            self = decoded
        }
        catch let decodeError
        {
            print("Failed to initialize Server Config. Error decoding data")
            print("Error: \(decodeError)")
            print("Data: \(data)")
            return nil
        }
    }
    
    public func createSong() -> Data?
    {
        let encoder = SongEncoder()
        
        do
        {
            let result: Data = try encoder.encode(self)
            return result
        }
        catch let encodeError
        {
            print("Failed to encode ServerConfig instance.")
            print("Error: \(encodeError)")
            return nil
        }
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
