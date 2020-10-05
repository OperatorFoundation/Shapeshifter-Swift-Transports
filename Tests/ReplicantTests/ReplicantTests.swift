//
//  ReplicantTests.swift
//  ReplicantTests
//
//  Created by Adelita Schule on 11/21/18.
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

import XCTest

@testable import Replicant

import Network
import ReplicantSwift
import SwiftQueue
import CryptoKit
import Song
import Logging

class ReplicantTests: XCTestCase
{
    func testServerConfigEncode()
    {
        let testIPString = "127.0.0.1"
        let testPort: UInt16 = 1234
        let host = NWEndpoint.Host(testIPString)
        guard let port = NWEndpoint.Port(rawValue: testPort)
            else
        {
            print("\nUnable to initialize port.\n")
            XCTFail()
            return
        }
        
        let serverConfig = ServerConfig(withPort: port, andHost: host)
                
        XCTAssertNotNil(serverConfig.createSong())
    }
    
    func testServerConfigDecode()
    {
        let testIPString = "127.0.0.1"
        let testPort: UInt16 = 1234
        let host = NWEndpoint.Host(testIPString)
        guard let port = NWEndpoint.Port(rawValue: testPort)
            else
        {
            print("\nUnable to initialize port.\n")
            XCTFail()
            return
        }
        
        let serverConfig = ServerConfig(withPort: port, andHost: host)
        guard let configData: Data = serverConfig.createSong()
        else
        {
            XCTFail()
            return
        }
        
        guard let decodedConfig = ServerConfig(data: configData)
        else
        {
            XCTFail()
            return
        }
        
        XCTAssertEqual(serverConfig, decodedConfig)
    }
    
    func testEmptyConfigConnection()
    {
        let testIPString = "127.0.0.1"
        let testPort: UInt16 = 1234
        let connected = expectation(description: "Connection callback called")
        let sent = expectation(description: "TCP data sent")
        
        let host = NWEndpoint.Host(testIPString)
        guard let port = NWEndpoint.Port(rawValue: testPort)
            else
        {
            print("\nUnable to initialize port.\n")
            XCTFail()
            return
        }
        
        // Make a Client Connection
        guard let replicantClientConfig = ReplicantConfig<SilverClientConfig>(polish: nil, toneBurst: nil)
            else
        {
            print("\nUnable to create ReplicantClient config.\n")
            XCTFail()
            return
        }
        
        let clientConnectionFactory = ReplicantConnectionFactory(host: host, port: port, config: replicantClientConfig, log: Logging.Logger(label: "test"))
        guard var clientConnection = clientConnectionFactory.connect(using: .tcp)
            else
        {
            XCTFail()
            return
        }
        
        clientConnection.stateUpdateHandler =
        {
            state in
            
            switch state
            {
            case NWConnection.State.ready:
                print("\nConnected state ready\n")
                connected.fulfill()
            default:
                print("\nReceived a state other than ready: \(state)\n")
                return
            }
        }
        
        clientConnection.start(queue: .global())
        
        let godot = expectation(description: "forever")
        wait(for: [connected, sent, godot], timeout: 3000)
    }

    func testConnection()
    {
        let chunkSize: UInt16 = 2000
        let chunkTimeout: Int = 1000
        // let aesOverheadSize = 113
        // let unencryptedChunkSize = chunkSize - UInt16(aesOverheadSize + 2)
        let testIPString = "127.0.0.1"
        let testPort: UInt16 = 1234
        let serverPublicKey = P256.KeyAgreement.PrivateKey().publicKey
        let connected = expectation(description: "Connection callback called")
        let sent = expectation(description: "TCP data sent")
        
        let host = NWEndpoint.Host(testIPString)
        guard let port = NWEndpoint.Port(rawValue: testPort)
            else
        {
            print("\nUnable to initialize port.\n")
            XCTFail()
            return
        }
        
        // Make a Client Connection
        
        // FIXME: PolishClientConfig
        guard let replicantClientConfig = ReplicantConfig<SilverClientConfig>(polish: nil, toneBurst: nil)
            else
        {
            print("\nUnable to create ReplicantClient config.\n")
            XCTFail()
            return
        }
        
        let clientConnectionFactory = ReplicantConnectionFactory(host: host, port: port, config: replicantClientConfig, log: Logger(label: "test"))
        guard var clientConnection = clientConnectionFactory.connect(using: .tcp)
            else
        {
            XCTFail()
            return
        }
        
        clientConnection.stateUpdateHandler =
        {
            state in
            
            switch state
            {
            case NWConnection.State.ready:
                print("\nConnected state ready\n")
                connected.fulfill()
            default:
                print("\nReceived a state other than ready: \(state)\n")
                return
            }
        }
        
        clientConnection.start(queue: .global())
        
        let godot = expectation(description: "forever")
        wait(for: [connected, sent, godot], timeout: 3000)
    }

}
