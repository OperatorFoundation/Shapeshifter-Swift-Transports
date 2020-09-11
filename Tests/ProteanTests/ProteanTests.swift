//
//  Shapeshifter_ProteanTests.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Adelita Schule on 8/24/18.
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
import Foundation
import Transport
import Protean
import ProteanSwift
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Network
#elseif os(Linux)
import NetworkLinux
#endif


@testable import Protean

class ProteanTests: XCTestCase
{
    let ipAddressString = ""
    let portString = "1234"
    
    func makeSampleProteanConfig() -> Protean.Config
    {
        return Protean.Config(byteSequenceConfig: sampleSequenceConfig(),
                              encryptionConfig: sampleEncryptionConfig(),
                              headerConfig: sampleHeaderConfig())
    }
    
    func testProteanConnection()
    {
        guard let portUInt = UInt16(portString), let port = NWEndpoint.Port(rawValue: portUInt)
            else
        {
            print("Unable to resolve port for test")
            XCTFail()
            return
        }
        guard let ipv4Address = IPv4Address(ipAddressString)
            else
        {
            print("Unable to resolve ipv4 address for test")
            XCTFail()
            return
        }
        
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let connected = expectation(description: "Connected to server.")
        let connectionFactory = ProteanConnectionFactory(host: host, port: port, config: makeSampleProteanConfig())
        
        guard var connection = connectionFactory.connect(using: .udp)
        else
        {
            XCTFail()
            return
        }
        
        connection.stateUpdateHandler =
        {
            (newState) in
            
            print("\nCURRENT STATE = \(newState))\n")
            
            switch newState
            {
            case .ready:
                print("\n🚀 Protean connection is ready  🚀\n")
                connected.fulfill()
                
            case .cancelled:
                print("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
                
            case .failed(let error):
                print("\n Connection Failed")
                print("Failure Error: \(error.localizedDescription)\n")
                
            default:
                print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
            }
        }
        
        connection.start(queue: DispatchQueue(label: "TestQueue"))
        
        waitForExpectations(timeout: 30)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }

    }
    
    func testProteanSend()
    {
        guard let portUInt = UInt16(portString), let port = NWEndpoint.Port(rawValue: portUInt)
            else
        {
            print("Unable to resolve port for test")
            XCTFail()
            return
        }
        guard let ipv4Address = IPv4Address(ipAddressString)
            else
        {
            print("Unable to resolve ipv4 address for test")
            XCTFail()
            return
        }
        
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let message = "GET / HTTP/1.0\n\n"
        let connected = expectation(description: "Connected to server.")
        let wrote = expectation(description: "Wrote data to server.")
        
        let connectionFactory = ProteanConnectionFactory(host: host, port: port, config: makeSampleProteanConfig())
        
        guard var connection = connectionFactory.connect(using: .udp)
            else
        {
            XCTFail()
            return
        }
        
        connection.stateUpdateHandler = {
            (newState) in
            
            print("\nCURRENT STATE = \(newState))\n")
            
            switch newState
            {
            case .ready:
                print("\n🚀 Protean connection is ready  🚀\n")
                connected.fulfill()
                
                // Send
                connection.send(content: message.data(using: .ascii),
                                contentContext: .defaultMessage,
                                isComplete: true,
                                completion: NWConnection.SendCompletion.contentProcessed(
                { (maybeError) in
                    
                    if let error = maybeError
                    {
                        print("\nProtean connection received an error on send: \(error.localizedDescription)\n")
                        XCTFail()
                    }
                    else
                    {
                        wrote.fulfill()
                    }
                }))
                
            case .cancelled:
                print("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
                
            case .failed(let error):
                print("\n🐒💨  Connection Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                
            default:
                print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
            }
        }
        
        connection.start(queue: DispatchQueue(label: "TestQueue"))
        
        waitForExpectations(timeout: 30)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func testProteanSendReceive()
    {
        guard let portUInt = UInt16("1234"), let port = NWEndpoint.Port(rawValue: portUInt)
            else
        {
            print("Unable to resolve port for test")
            XCTFail()
            return
        }
        
        guard let ipv4Address = IPv4Address("192.168.129.5")
            else
        {
            print("Unable to resolve ipv4 address for test")
            XCTFail()
            return
        }
        
        let connected = expectation(description: "Connected to server.")
        let wrote = expectation(description: "Wrote data to server.")
        let read = expectation(description: "Read data from the server.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let message = "Hello Hello"
        let connectionFactory = ProteanConnectionFactory(host: host, port: port, config: makeSampleProteanConfig())
        
        guard var connection = connectionFactory.connect(using: .udp)
            else
        {
            XCTFail()
            return
        }
        
        connection.stateUpdateHandler =
        {
            (newState) in
            
            print("\nCURRENT STATE = \(newState))\n")
            
            switch newState
            {
            case .ready:
                print("\n🚀 Protean connection is ready  🚀\n")
                connected.fulfill()
                
                // Send
                connection.send(content: message.data(using: .ascii),
                                contentContext: .defaultMessage,
                                isComplete: true,
                                completion: NWConnection.SendCompletion.contentProcessed(
                {
                    (maybeError) in
                    
                    if let error = maybeError
                    {
                        print("\nProtean connection received an error on send: \(error.localizedDescription)\n")
                        XCTFail()
                    }
                    else
                    {
                        wrote.fulfill()
                    }
                }))
                
                //Receive
                connection.receive(completion:
                {
                    (maybeData, maybeContext, connectionComplete, maybeError) in
                    
                    if let data = maybeData
                    {
                        print("\nReceived some datas: \(data)\n")
                        read.fulfill()
                    }
                    else if let error = maybeError
                    {
                        print("\nReceived an error while attempting to read from Protean Connection: \(error.localizedDescription)\n")
                        XCTFail()
                    }
                })
                
            case .cancelled:
                print("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
                
            case .failed(let error):
                print("\n🐒💨  Connection Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                XCTFail()
                
            default:
                print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
            }
        }
        
        connection.start(queue: DispatchQueue(label: "TestQueue"))
        
        waitForExpectations(timeout: 30)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    
}
