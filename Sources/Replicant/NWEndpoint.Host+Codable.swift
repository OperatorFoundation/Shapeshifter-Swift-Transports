//
//  NWEnpoint.Host+Codable.swift
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

#if os(Linux)
import NetworkLinux
#else
import Network
#endif

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
