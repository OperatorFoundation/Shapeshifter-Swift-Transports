//
//  NWEndpoint.Port+Codable.swift
//  Replicant
//
//  Created by Mafalda on 1/29/19.
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

import ReplicantSwift

#if os(Linux)
import NetworkLinux
#else
import Network
#endif

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

