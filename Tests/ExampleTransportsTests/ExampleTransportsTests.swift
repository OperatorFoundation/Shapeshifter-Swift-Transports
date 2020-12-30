//
//  ExampleTransportsTests.swift
//  WispTests
//
//  Created by Adelita Schule on 8/13/18.
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
import XCTest
import Transport

#if os(Linux)
import NetworkLinux
#else
import Network
#endif


@testable import ExampleTransports

class ExampleTransportsTests: XCTestCase
{
    
    func testRot13Connection()
    {
        guard let portUInt = UInt16("80"), let port = NWEndpoint.Port(rawValue: portUInt)
            else
        {
            print("Unable to resolve port for test")
            XCTFail()
            return
        }
        guard let ipv4Address = IPv4Address("172.217.9.174")
            else
        {
            print("Unable to resolve ipv4 address for test")
            XCTFail()
            return
        }
        
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let connectionFactory = Rot13ConnectionFactory(host: host, port: port, logger: Logger(label: "TestRot13"))
        let maybeConnection = connectionFactory.connect(using: .tcp)
        
        XCTAssertNotNil(maybeConnection)
    }
    
    func testRot13Send()
    {
        guard let portUInt = UInt16("80"), let port = NWEndpoint.Port(rawValue: portUInt)
            else
        {
            print("Unable to resolve port for test")
            XCTFail()
            return
        }
        guard let ipv4Address = IPv4Address("172.217.9.174")
            else
        {
            print("Unable to resolve ipv4 address for test")
            XCTFail()
            return
        }
        
        let connected = expectation(description: "Connected to the server.")
        let wrote = expectation(description: "Wrote data to the server.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let connectionFactory = Rot13ConnectionFactory(host: host, port: port, logger: Logger(label: "TestRot13") )
        let maybeConnection = connectionFactory.connect(using: .tcp)
        XCTAssertNotNil(maybeConnection)
        
        guard var connection = maybeConnection
            else
        {
            return
        }
        
        connection.stateUpdateHandler =
        {
            (newState) in
            
            print("CURRENT STATE = \(newState))")
            
            switch newState
            {
            case .ready:
                print("\n🚀 open() called on tunnel connection  🚀\n")
                let message = "GET / HTTP/1.0\n\n"
                connected.fulfill()
                
                connection.send(content: message.data(using: .ascii),
                                contentContext: .defaultMessage,
                                isComplete: true,
                                completion: NWConnection.SendCompletion.contentProcessed(
                {
                    (error) in
                    
                    if error == nil
                    {
                        wrote.fulfill()
                        print("No ERROR")
                    }
                        
                    else
                    {
                        print("RECEIVED A SEND ERROR: \(String(describing: error))")
                    }
                }))
                
            case .cancelled:
                print("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
                
            case .failed(let error):
                print("\n🐒💨  Connection Failed  🐒💨\n")
                print("Failure Error: \(error.localizedDescription)")
                
            default:
                print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
            }
        }
        
        maybeConnection?.start(queue: DispatchQueue(label: "TestQueue"))
        
        waitForExpectations(timeout: 60)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func testRot13SendReceive()
    {
        guard let portUInt = UInt16("80"), let port = NWEndpoint.Port(rawValue: portUInt)
            else
        {
            print("Unable to resolve port for test")
            XCTFail()
            return
        }
        guard let ipv4Address = IPv4Address("172.217.9.174")
            else
        {
            print("Unable to resolve ipv4 address for test")
            XCTFail()
            return
        }
        
        let connected = expectation(description: "Connected to the server.")
        let wrote = expectation(description: "Wrote data to the server.")
        let read = expectation(description: "Read data from the server.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let connectionFactory = Rot13ConnectionFactory(host: host, port: port, logger: Logger(label: "TestRot13"))
        let maybeConnection = connectionFactory.connect(using: .tcp)
        
        XCTAssertNotNil(maybeConnection)
        
        guard var connection = maybeConnection
            else
        {
            return
        }
        
        connection.stateUpdateHandler =
            {
                (newState) in
                
                print("CURRENT STATE = \(newState))")
                
                switch newState
                {
                case .ready:
                    print("\n🚀 open() called on tunnel connection  🚀\n")
                    let message = "GET / HTTP/1.0\n\n"
                    connected.fulfill()
                    
                    connection.send(content: message.data(using: String.Encoding.ascii),
                                    contentContext: .defaultMessage,
                                    isComplete: true,
                                    completion: NWConnection.SendCompletion.contentProcessed(
                    {
                        (error) in
                        
                        if error == nil
                        {
                            wrote.fulfill()
                            print("No ERROR")
                        }
                            
                        else
                        {
                            print("RECEIVED A SEND ERROR: \(String(describing: error))")
                        }
                    }))
                    
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 1500, completion:
                    {
                        (maybeData, maybeContext, connectionComplete, maybeError) in
                        
                        print("\nTo receive is also nice.")
                        print("Data? \(String(describing: maybeData))")
                        if let data = maybeData
                        {
                            let responseString = String(data: data, encoding: .ascii)
                            print("Data to String? \(responseString!)")
                        }
                        print("Context? \(String(describing: maybeContext))")
                        print("Connection Complete? \(String(describing: connectionComplete))")
                        print("Error? \(maybeError.debugDescription)\n")
                        
                        if maybeError != nil
                        {
                            switch maybeError!
                            {
                            case .posix(let posixError):
                                print("Received a posix error: \(posixError)")
                            case .tls(let tlsError):
                                print("Received a tls error: \(tlsError)")
                            case .dns(let dnsError):
                                print("Received a dns error: \(dnsError)")
                            default:
                                print("received an error: \(maybeError!)")
                            }
                        }
                        
                        if let data = maybeData
                        {
                            print("Received some datas: \(data)\n")
                            read.fulfill()
                        }
                    })
                    
                case .cancelled:
                    print("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
                    
                case .failed(let error):
                    print("\n🐒💨  Connection Failed  🐒💨\n")
                    print("Failure Error: \(error.localizedDescription)")
                    
                default:
                    print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
                }
        }
        
        maybeConnection?.start(queue: DispatchQueue(label: "TestQueue"))
        
        waitForExpectations(timeout: 20)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    

}
