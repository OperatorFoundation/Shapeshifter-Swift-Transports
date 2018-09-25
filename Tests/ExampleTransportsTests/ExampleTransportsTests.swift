//
//  ExampleTransportsTests.swift
//  WispTests
//
//  Created by Adelita Schule on 8/13/18.
//

import Foundation
import XCTest
import Transport
import Network


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
        let connectionFactory = Rot13ConnectionFactory(host: host, port: port)
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
        let connectionFactory = Rot13ConnectionFactory(host: host, port: port)
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
        let connectionFactory = Rot13ConnectionFactory(host: host, port: port)
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
                    
                    connection.receive(completion:
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
