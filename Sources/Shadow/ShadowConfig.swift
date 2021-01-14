//
//  ShadowConfig.swift
//  Shadow
//
//  Created by Mafalda on 8/18/20.
//

import CryptoKit
import Foundation

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
import CryptoKit
#else
import Crypto
#endif

public struct ShadowConfig
{
    public let password: String
    public let mode: CipherMode
    
    public init(password: String, mode: CipherMode)
    {
        self.password = password
        self.mode = mode
    }
}
