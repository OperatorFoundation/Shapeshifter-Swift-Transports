//
//  ShadowConfig.swift
//  Shadow
//
//  Created by Mafalda on 8/18/20.
//

import Foundation

import Song

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
import CryptoKit
#else
import Crypto
#endif

public struct ShadowConfig: Decodable
{
    public let password: String
    public let mode: CipherMode
    
    public init(password: String, mode: CipherMode)
    {
        self.password = password
        self.mode = mode
    }
    
    init?(from data: Data)
    {
        let songDecoder = SongDecoder()
        do
        {
            let decoded = try songDecoder.decode(ShadowConfig.self, from: data)
            self.init(password: decoded.password, mode: decoded.mode)
        }
        catch let decodeError
        {
            print("Error decoding Shadow Config data: \(decodeError)")
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
