//
//  Shapeshifter_WispTests.swift
//  Shapeshifter-WispTests
//
//  Created by Brandon Wiley on 10/31/17.
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
import XCTest
import Sodium
import Elligator
import NetworkExtension
import Transport
import Logging

#if os(Linux)
import NetworkLinux
#else
import Network
#endif

@testable import Wisp

class Shapeshifter_WispTests: XCTestCase
{
    let certString = "60RNHBMRrf+aOSPzSj8bD4ASGyyPl0mkaOUAQsAYljSkFB0G8B8m9fGvGJCpOxwoXS1baA"
    let ipAddressString = "159.203.158.90"
    let portString = "1234"
    let secretKeyMaterial = Data(repeating: 0x0A, count: keyMaterialLength)
    static let publicKey = Data([139, 210, 37, 89, 10, 47, 113, 85, 13, 53, 118, 181, 28, 8, 202, 146, 220, 206, 224, 143, 24, 159, 235, 136, 173, 194, 120, 171, 201, 54, 238, 76])
    static let privateKey = Data([198, 167, 133, 212, 83, 74, 53, 24, 178, 34, 178, 148, 128, 202, 15, 70, 247, 196, 26, 159, 184, 238, 185, 113, 19, 137, 138, 135, 39, 137, 55, 15])
    static let elligatorRepresentative = Data([95, 226, 105, 55, 70, 208, 53, 164, 16, 88, 68, 55, 89, 16, 147, 91, 38, 140, 125, 101, 237, 25, 154, 12, 82, 12, 4, 158, 252, 206, 79, 1])
    
    let maxWaitSeconds: Double = 25
    let toEncode = Data(repeating: 0x0A, count: 50)
    let testClientKeypair = Keypair(publicKey: publicKey, privateKey: privateKey, representative: elligatorRepresentative)
    //let wispProtocol = WispProtocol(connection: Shapeshifter_WispTests.fakeTCPConnection as TCPConnection, cert: Shapeshifter_WispTests.certString, iatMode: false)
    
    var wispConnection: WispConnection?
    
    func testJSONConfig()
    {
        let fileURL = NSURL.fileURL(withPath: Bundle.module.path(forResource: "obfs4ConfigExample", ofType: "json")!)
        guard let _ = WispConfig(path: fileURL.path)
        else
        {
            XCTFail()
            return
        }
    }
    
    //MARK: WispCoding
    
    func testWispEncoderInit()
    {
        if let encoder = WispEncoder(withKey: secretKeyMaterial, logger: Logger(label: "test"))
        {
            XCTAssertEqual(encoder.secretBoxKey.count, keyLength)
            XCTAssertEqual(encoder.nonce.counter, 0)
            XCTAssertEqual(encoder.nonce.prefix.count, noncePrefixLength)
            XCTAssertEqual(encoder.drbg.sip.count, 16)
            XCTAssertEqual(encoder.drbg.ofb.count, siphashSize)
        }
        else
        {
            XCTFail("Unable to initialize a wisp encoder.")
        }
    }
    
    func testnextBlock()
    {
        /*
         Original OFB:
         [10, 10, 10, 10, 10, 10, 10, 10]
         Next Block:
         [236, 69, 46, 10, 77, 178, 64, 212]
         */
        var wispEncoder = WispEncoder(withKey: secretKeyMaterial, logger: Logger(label: "test"))
        let expectedOutcome = Data([236, 69, 46, 10, 77, 178, 64, 212])
        let nextBlock = wispEncoder!.drbg.nextBlock()
        XCTAssertEqual(nextBlock, expectedOutcome)
    }
    
    func testEncodePayload()
    {
        var wispEncoder = WispEncoder(withKey: secretKeyMaterial, logger: Logger(label: "test"))
        let encoded = wispEncoder?.encode(payload: toEncode)
        XCTAssertNotNil(encoded)
        XCTAssertNotEqual(toEncode, encoded)
        
        print("ToEncode count: \(toEncode.count)")
        print("Encoded count: \(String(describing: encoded?.count))")
        print(encoded!.bytes)
    }
    
    func testDecodePayloadLength()
    {
        var wispEncoder = WispEncoder(withKey: secretKeyMaterial, logger: Logger(label: "test"))
        let knownCorrectLength = UInt16(toEncode.count + 16)
        let encoded = wispEncoder?.encode(payload: toEncode)
        XCTAssertNotNil(encoded)
        XCTAssertNotEqual(toEncode, encoded)
        XCTAssertEqual(encoded!.count, toEncode.count + 16 + 2)
        
        
        var wispDecoder = WispDecoder(withKey: secretKeyMaterial, logger: Logger(label: "test"))
        let lengthData = encoded![0 ..< lengthLength]
        let unobfuscatedLength = wispDecoder?.unobfuscate(obfuscatedLength: lengthData)

        print("\nlengthData: \(lengthData.bytes)")
        print("Encoded count: \(encoded!.count)")
        print("To Encode Count: \(toEncode.count)")
        print("unobfuscatedLength: \(String(describing: unobfuscatedLength))")
        print("knownCorrectLength: \(knownCorrectLength)\n")
        
        XCTAssertEqual(knownCorrectLength, unobfuscatedLength)
    }
    
    func testLengthObfuscation()
    {
        let testLength: UInt16 = 300
        var wispDecoder = WispDecoder(withKey: secretKeyMaterial, logger: Logger(label: "test"))
        var wispEncoder = WispEncoder(withKey: secretKeyMaterial, logger: Logger(label: "test"))
        let obfuscatedLength = wispEncoder?.obfuscate(length: testLength)
        let unobfuscatedLength = wispDecoder?.unobfuscate(obfuscatedLength: obfuscatedLength!)
        
        XCTAssertEqual(unobfuscatedLength, testLength)
    }
    
    func testDecodeFramesBuffer()
    {
        var wispDecoder = WispDecoder(withKey: secretKeyMaterial, logger: Logger(label: "test"))
        var wispEncoder = WispEncoder(withKey: secretKeyMaterial, logger: Logger(label: "test"))
        let encodedTestData = wispEncoder?.encode(payload: toEncode)
        let decodedResult = wispDecoder?.decode(framesBuffer: encodedTestData!)
        XCTAssertNotNil(decodedResult)
        
        if decodedResult != nil
        {
            switch decodedResult!
            {
            case let .success(decodedData, _):
                XCTAssertEqual(decodedData, toEncode)
            default:
                print(decodedResult.debugDescription)
                XCTFail()
            }
        }
        
    }
    
    func testRandomInRange()
    {
        guard let decoder = WispDecoder(withKey: secretKeyMaterial, logger: Logger(label: "test"))
        else
        {
            print("Unable to init decoder for test.")
            return
        }
        
        let ran1 = decoder.random(inRange: minFrameLength ..< maxFrameLength + 1)
        let ran2 = decoder.random(inRange: minFrameLength ..< maxFrameLength + 1)
        
        XCTAssertNotEqual(ran1, ran2)
        XCTAssert(ran1 < maxFrameLength + 1)
        XCTAssert(ran1 > minFrameLength - 1)
        XCTAssert(ran2 < maxFrameLength + 1)
        XCTAssert(ran2 > minFrameLength - 1)
    }
    
    //MARK: Network Tests
    
    func testNetworkUDPConnectionSendReceive()
    {
        guard let portUInt = UInt16("1234"), let port = NWEndpoint.Port(rawValue: portUInt)
            else
        {
            print("Unable to resolve port for test")
            XCTFail()
            return
        }
        
//        guard let ipv4Address = IPv4Address("172.217.9.174") //Google
        guard let ipv4Address = IPv4Address("192.168.129.5")
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
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        let maybeConnection = connectionFactory.connect(using: .udp)
        
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
                let message = "Hello Hello"
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
                        print("\nNo ERROR\n")
                    }
                        
                    else
                    {
                        print("\n⛑  RECEIVED A SEND ERROR: \(String(describing: error))\n")
                        XCTFail()
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
                    print("\n⛑  Error? \(maybeError.debugDescription)\n")
                    
                    if maybeError != nil
                    {
                        switch maybeError!
                        {
                        case .posix(let posixError):
                            print("\n⛑  Received a posix error: \(posixError)")
                        case .tls(let tlsError):
                            print("\n⛑  Received a tls error: \(tlsError)")
                        case .dns(let dnsError):
                            print("\n⛑  Received a dns error: \(dnsError)")
                        }
                        
                        XCTFail()
                    }
                    
                    if let data = maybeData
                    {
                        print("Received some datas: \(data)\n")
                        read.fulfill()
                        
                        connection.stateUpdateHandler = nil
                    }
                })
                
            case .cancelled:
                print("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
                
            case .failed(let error):
                print("\n🐒💨  Connection Failed  🐒💨\n")
                print("⛑  Failure Error: \(error.localizedDescription)")
                XCTFail()
                
            default:
                print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
            }
        }
        
        maybeConnection?.start(queue: DispatchQueue(label: "TestQueue"))
        
        waitForExpectations(timeout: maxWaitSeconds)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func testNetworkTCPConnectionConnect()
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
        
        let connected = expectation(description: "Connected to server.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        var maybeConnection = connectionFactory.connect(using: .tcp)
        XCTAssertNotNil(maybeConnection)

        maybeConnection!.stateUpdateHandler =
        {
            (newState) in
                        
            print("CURRENT STATE = \(newState))")
            
            switch newState
            {
            case .ready:
                print("\n🚀 open() called on tunnel connection  🚀\n")
                connected.fulfill()
                
            case .cancelled:
                print("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
                
            case .failed(let error):
                print("\n🐒💨  Connection Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                
            default:
                print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
            }
        }
        
        maybeConnection?.start(queue: DispatchQueue(label: "TestQueue"))

        waitForExpectations(timeout: maxWaitSeconds)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func testNetworkTCPConnectionSend()
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
        
        let connected = expectation(description: "Connected to server.")
        let wrote = expectation(description: "Wrote data to server.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        var maybeConnection = connectionFactory.connect(using: .tcp)
        XCTAssertNotNil(maybeConnection)

        maybeConnection?.stateUpdateHandler =
        {
            (newState) in
            
            print("CURRENT STATE = \(newState))")
            
            switch newState
            {
            case .ready:
                print("\n🚀 open() called on tunnel connection  🚀\n")
                let message = "GET / HTTP/1.0\n\n"
                
                connected.fulfill()
                let sendCompletion = NWConnection.SendCompletion.contentProcessed(
                {
                    (error) in
                    
                    if error == nil
                    {
                        wrote.fulfill()
                        print("No ERROR, sending again.")
                        maybeConnection?.send(content: message.data(using: String.Encoding.ascii),
                                              contentContext: .defaultMessage,
                                              isComplete: true,
                                              completion: .contentProcessed(
                                                {
                                                    maybeError in
                                                    
                                                    print("Send completion for second send reached.")
                                                    
                                                }))
                    }
                    
                    else
                    {
                        print("RECEIVED A SEND ERROR: \(String(describing: error))")
                    }
                })
                
                maybeConnection?.send(content: message.data(using: String.Encoding.ascii),
                                      contentContext: .defaultMessage,
                                      isComplete: true,
                                      completion: sendCompletion)
                
            case .cancelled:
                print("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
                
            case .failed(let error):
                print("\n🐒💨  Connection Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                
            default:
                print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
            }
        }
        
        maybeConnection?.start(queue: DispatchQueue(label: "TestQueue"))
        
        waitForExpectations(timeout: maxWaitSeconds)
        {
            (maybeError) in
            
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func testNetworkTCPConnectionSendReceive()
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
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
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
                                isComplete: false,
                                completion: NWConnection.SendCompletion.contentProcessed(
                {
                    (error) in
                    
                    if error == nil
                    {
                        wrote.fulfill()
                        print("\nNo ERROR\n")
                    }
                        
                    else
                    {
                        print("\n⛑  RECEIVED A SEND ERROR: \(String(describing: error))\n")
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
                    print("\n⛑  Error? \(maybeError.debugDescription)\n")
                    
                    if maybeError != nil
                    {
                        switch maybeError!
                        {
                        case .posix(let posixError):
                            print("\n⛑  Received a posix error: \(posixError)")
                        case .tls(let tlsError):
                            print("\n⛑  Received a tls error: \(tlsError)")
                        case .dns(let dnsError):
                            print("\n⛑  Received a dns error: \(dnsError)")
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
                print("⛑  Failure Error: \(error.localizedDescription)")
                
            default:
                print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
            }
        }
        
        maybeConnection?.start(queue: DispatchQueue(label: "TestQueue"))
        
        waitForExpectations(timeout: maxWaitSeconds)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func testNetworkTCPConnectionSendTwice()
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
        let wroteTwice = expectation(description: "Wrote data to the server a second time.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
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
                
                let bigMessage = Data(count: 1442)

                connection.send(content: bigMessage,
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
                        print("\nRECEIVED A SEND ERROR: \(String(describing: error))\n")
                    }
                }))
                
                connection.send(content: message.data(using: String.Encoding.ascii),
                                contentContext: .defaultMessage,
                                isComplete: false,
                                completion: NWConnection.SendCompletion.contentProcessed(
                {
                    (error) in

                    if error == nil
                    {
                        wroteTwice.fulfill()
                        print("No ERROR")
                    }

                    else
                    {
                        print("\nRECEIVED A SEND ERROR: \(String(describing: error))\n")
                    }
                }))
                
            case .preparing:
                print("\n⌛️  Preparing connection... ⌛️\n")
                
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
        
        waitForExpectations(timeout: maxWaitSeconds)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    
    //MARK: WispTCPConnection
    
    func testWispConnection()
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
        
        let connected = expectation(description: "Connected to server.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let wispFactory = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false, logger: Logger(label: "test"))
        var maybeConnection = wispFactory.connect(using: .tcp)
        XCTAssertNotNil(maybeConnection)

        maybeConnection?.stateUpdateHandler =
        {
            (newState) in
            
            print("CURRENT STATE = \(newState))")
            
            switch newState
            {
            case .preparing:
                print("\n⌛️  Preparing connection... ⌛️\n")
                
            case .ready:
                print("\n🚀 wisp connection is ready  🚀\n")
                connected.fulfill()
                
            case .cancelled:
                print("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
                
            case .failed(let error):
                print("\n🐒💨  Connection Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                
            default:
                print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
            }
        }
        
        maybeConnection?.start(queue: DispatchQueue(label: "TestQueue"))
        
        waitForExpectations(timeout: 30)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func testWispSend()
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
        
        let message = "GET / HTTP/1.0\n\n"
        let connected = expectation(description: "Connected to server.")
        let wrote = expectation(description: "Wrote data to server.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let wispFactory = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false, logger: Logger(label: "test"))
        let maybeConnection = wispFactory.connect(using: .tcp)
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
                print("\n🚀 wisp connection is ready  🚀\n")
                connected.fulfill()
                
                connection.send(content: message.data(using: .ascii),
                                contentContext: .defaultMessage,
                                isComplete: true,
                                completion: NWConnection.SendCompletion.contentProcessed(
                {
                    (maybeError) in
                    
                    if let error = maybeError
                    {
                        print("\nWisp connection received an error on send: \(error.localizedDescription)\n")
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
    
    func testWispSendReceive()
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
        
        let message = "GET / HTTP/1.0\n\n"
        let connected = expectation(description: "Connected to server.")
        let wrote = expectation(description: "Wrote data to server.")
        let read = expectation(description: "Read data from the server.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let wispFactory = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false, logger: Logger(label: "test"))
        let maybeConnection = wispFactory.connect(using: .tcp)
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
                print("\n🚀 wisp connection is ready  🚀\n")
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
                        print("\nWisp connection received an error on send: \(error.localizedDescription)\n")
                        XCTFail()
                    }
                    else
                    {
                        wrote.fulfill()
                    }
                }))
                
                //Receive
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1500, completion:
                {
                    (maybeData, maybeContext, connectionComplete, maybeError) in
                    
                    if let data = maybeData
                    {
                        print("\nReceived some datas: \(data)\n")
                        read.fulfill()
                    }
                    else if let error = maybeError
                    {
                        print("\nReceived an error while attempting to read from Wisp Connection: \(error.localizedDescription)\n")
                    }
                })
                
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
    
    
    func testNewKeypair()
    {
        let maybeKeypair = newKeypair(logger: Logger(label: "test"))
        XCTAssertNotNil(maybeKeypair)
        
        if let new1stKeypair = maybeKeypair
        {
            XCTAssertEqual(new1stKeypair.publicKey.count, publicKeyLength)
            XCTAssertEqual(new1stKeypair.representative.count, representativeLength)
            
            // Do it all again!
            
            let maybe2ndKeypair = newKeypair(logger: Logger(label: "test"))
            XCTAssertNotNil(maybe2ndKeypair)
            
            if let new2ndKeypair = maybe2ndKeypair
            {
                XCTAssertEqual(new2ndKeypair.publicKey.count, publicKeyLength)
                XCTAssertEqual(new2ndKeypair.representative.count, representativeLength)
                XCTAssertNotEqual(new2ndKeypair.publicKey, new1stKeypair.publicKey)
                XCTAssertNotEqual(new2ndKeypair.privateKey, new1stKeypair.privateKey)
                XCTAssertNotEqual(new2ndKeypair.representative, new1stKeypair.representative)
            }
        }
    }
    
    func testClientHandshakeData()
    {
        let sessionKey = Keypair(publicKey: Shapeshifter_WispTests.publicKey, privateKey: Shapeshifter_WispTests.privateKey, representative: Shapeshifter_WispTests.elligatorRepresentative)
        let clientHandshake = ClientHandshake(certString: certString, sessionKey: sessionKey, logger: Logger(label: "test"))
        
        // Did we init the handshake?
        XCTAssertNotNil(clientHandshake)
        
        // Is the handshake computed property returning a value?
        XCTAssertNotNil(clientHandshake?.data)
        
        if let handshakeData = clientHandshake?.data
        {
            // The first bit of handshake data should be our elligator representative
            let rep = handshakeData[0 ..< representativeLength]
            XCTAssertEqual(rep, Shapeshifter_WispTests.elligatorRepresentative)
        }
    }
    
    /// Also tests unpack(certData:) and serverCert(fromString:)
    func testUnpackCertString()
    {
        let maybeCert = unpack(certString: certString)
        XCTAssertNotNil(maybeCert)
        
        if let cert = maybeCert
        {
            XCTAssertEqual(cert.nodeID.count, nodeIDLength)
            /// XCTAssertEqual(cert.nodeID, nodeID)
            /// TODO: This needs to be tested when we have a cert and public key shared with the server and know what it is.
            /// XCTAssertEqual(cert.publicKey, publicKey)
            XCTAssertEqual(cert.publicKey.count, publicKeyLength)
        }
    }
    
}
