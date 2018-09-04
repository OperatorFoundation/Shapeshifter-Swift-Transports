//
//  Shapeshifter_WispTests.swift
//  Shapeshifter-WispTests
//
//  Created by Brandon Wiley on 10/31/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import XCTest
import Sodium
import Elligator
import NetworkExtension
import Transport
import Network


@testable import Wisp

class Shapeshifter_WispTests: XCTestCase
{
    let certString = "60RNHBMRrf+aOSPzSj8bD4ASGyyPl0mkaOUAQsAYljSkFB0G8B8m9fGvGJCpOxwoXS1baA"
    let ipAddressString = "159.203.158.90"
    let portString = "1234"
    let secretKeyMaterial = Data(repeating: 0x0A, count: keyMaterialLength)
    static let publicKey = Data(bytes: [139, 210, 37, 89, 10, 47, 113, 85, 13, 53, 118, 181, 28, 8, 202, 146, 220, 206, 224, 143, 24, 159, 235, 136, 173, 194, 120, 171, 201, 54, 238, 76])
    static let privateKey = Data(bytes: [198, 167, 133, 212, 83, 74, 53, 24, 178, 34, 178, 148, 128, 202, 15, 70, 247, 196, 26, 159, 184, 238, 185, 113, 19, 137, 138, 135, 39, 137, 55, 15])
    static let elligatorRepresentative = Data(bytes: [95, 226, 105, 55, 70, 208, 53, 164, 16, 88, 68, 55, 89, 16, 147, 91, 38, 140, 125, 101, 237, 25, 154, 12, 82, 12, 4, 158, 252, 206, 79, 1])
    
    let maxWaitSeconds: Double = 20
    let toEncode = Data(repeating: 0x0A, count: 50)
    let testClientKeypair = Keypair(publicKey: publicKey, privateKey: privateKey, representative: elligatorRepresentative)
    //let wispProtocol = WispProtocol(connection: Shapeshifter_WispTests.fakeTCPConnection as TCPConnection, cert: Shapeshifter_WispTests.certString, iatMode: false)
    
    var wispConnection: WispConnection?
    
    //MARK: WispCoding
    
    func testWispEncoderInit()
    {
        if let encoder = WispEncoder(withKey: secretKeyMaterial)
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
        var wispEncoder = WispEncoder(withKey: secretKeyMaterial)
        let expectedOutcome = Data(bytes: [236, 69, 46, 10, 77, 178, 64, 212])
        let nextBlock = wispEncoder!.drbg.nextBlock()
        XCTAssertEqual(nextBlock, expectedOutcome)
    }
    
    func testEncodePayload()
    {
        var wispEncoder = WispEncoder(withKey: secretKeyMaterial)
        let encoded = wispEncoder?.encode(payload: toEncode)
        XCTAssertNotNil(encoded)
        XCTAssertNotEqual(toEncode, encoded)
        
        print("ToEncode count: \(toEncode.count)")
        print("Encoded count: \(String(describing: encoded?.count))")
        print(encoded!.bytes)
    }
    
    func testDecodePayloadLength()
    {
        var wispEncoder = WispEncoder(withKey: secretKeyMaterial)
        let knownCorrectLength = UInt16(toEncode.count + 16)
        let encoded = wispEncoder?.encode(payload: toEncode)
        XCTAssertNotNil(encoded)
        XCTAssertNotEqual(toEncode, encoded)
        XCTAssertEqual(encoded!.count, toEncode.count + 16 + 2)
        
        
        var wispDecoder = WispDecoder(withKey: secretKeyMaterial)
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
        var wispDecoder = WispDecoder(withKey: secretKeyMaterial)
        var wispEncoder = WispEncoder(withKey: secretKeyMaterial)
        let obfuscatedLength = wispEncoder?.obfuscate(length: testLength)
        let unobfuscatedLength = wispDecoder?.unobfuscate(obfuscatedLength: obfuscatedLength!)
        
        XCTAssertEqual(unobfuscatedLength, testLength)
    }
    
    func testDecodeFramesBuffer()
    {
        var wispDecoder = WispDecoder(withKey: secretKeyMaterial)
        var wispEncoder = WispEncoder(withKey: secretKeyMaterial)
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
        guard let decoder = WispDecoder(withKey: secretKeyMaterial)
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
    
    //MARK: WispTCPConnection
    
    func testNetworkConnectionConnect()
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
        let parameters = NWParameters()
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        var maybeConnection = connectionFactory.connect(parameters)
        
        XCTAssertNotNil(maybeConnection)
        
        let connected = expectation(description: "Connected to server.")
        //let wrote = expectation(description: "Wrote data to server.")

        maybeConnection?.stateUpdateHandler =
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
    
    func testNetworkConnectionSend()
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
        let parameters = NWParameters()
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        var maybeConnection = connectionFactory.connect(parameters)
        
        XCTAssertNotNil(maybeConnection)
        
        let connected = expectation(description: "Connected to server.")
        let wrote = expectation(description: "Wrote data to server.")
        
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
                    let context = NWConnection.ContentContext()
                    let sendCompletion = NWConnection.SendCompletion.contentProcessed(
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
                    })
                    
                    maybeConnection?.send(content: message.data(using: String.Encoding.ascii), contentContext: context, isComplete: true, completion: sendCompletion)
                    
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
    
    func testNetworkConnectionSendReceive()
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
        let parameters = NWParameters()
        let context = NWConnection.ContentContext()
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        let maybeConnection = connectionFactory.connect(parameters)
        
        var lock: DispatchGroup
        lock = DispatchGroup.init()
        
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
                
                lock.enter()
                connection.send(content: message.data(using: String.Encoding.ascii), contentContext: context, isComplete: true, completion: NWConnection.SendCompletion.contentProcessed(
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
                    
                    lock.leave()
                }))
                lock.wait()
                
                lock.enter()
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
                        }
                    }
                    
                    if let data = maybeData
                    {
                        print("Received some datas: \(data)\n")
                        read.fulfill()
                    }
                    
                    lock.leave()
                })
                lock.wait()
                    
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
    
    func testNetworkConnectionSendTwice()
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
        let wroteTwice = expectation(description: "Wrote data to the server.")
        let parameters = NWParameters()
        let context = NWConnection.ContentContext()
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        let maybeConnection = connectionFactory.connect(parameters)
        
        var lock: DispatchGroup
        lock = DispatchGroup.init()
        
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
                    lock.enter()
                    connection.send(content: bigMessage, contentContext: context, isComplete: true, completion: NWConnection.SendCompletion.contentProcessed(
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
                            
                            lock.leave()
                    }))
                    lock.wait()
                    
                    lock.enter()
                    connection.send(content: message.data(using: String.Encoding.ascii), contentContext: context, isComplete: true, completion: NWConnection.SendCompletion.contentProcessed(
                        {
                            (error) in
                            
                            if error == nil
                            {
                                wroteTwice.fulfill()
                                print("No ERROR")
                            }
                                
                            else
                            {
                                print("RECEIVED A SEND ERROR: \(String(describing: error))")
                            }
                            
                            lock.leave()
                    }))
                    lock.wait()
                    
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
        
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let parameters = NWParameters()
        let wispFactory = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false)
        var maybeConnection = wispFactory.connect(parameters)
        
        XCTAssertNotNil(maybeConnection)
        
        let connected = expectation(description: "Connected to server.")
        
        maybeConnection?.stateUpdateHandler =
        {
            (newState) in
            
            print("CURRENT STATE = \(newState))")
            
            switch newState
            {
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
        let context = NWConnection.ContentContext()
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let parameters = NWParameters()
        let wispFactory = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false)
        let maybeConnection = wispFactory.connect(parameters)
        var lock: DispatchGroup
        
        lock = DispatchGroup.init()
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
                
                lock.enter()
                connection.send(content: message.data(using: .ascii), contentContext: context, isComplete: true, completion: NWConnection.SendCompletion.contentProcessed(
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
                    
                    lock.leave()
                }))
                
                lock.wait()
                
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
        let context = NWConnection.ContentContext()
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let parameters = NWParameters()
        let wispFactory = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false)
        let maybeConnection = wispFactory.connect(parameters)
        var lock: DispatchGroup
        
        lock = DispatchGroup.init()
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
                lock.enter()
                connection.send(content: message.data(using: .ascii), contentContext: context, isComplete: true, completion: NWConnection.SendCompletion.contentProcessed(
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
                        
                        lock.leave()
                }))
                lock.wait()
                
                //Receive
                lock.enter()
                
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
                        print("\nReceived an error while attempting to read from Wisp Connection: \(error.localizedDescription)\n")
                    }
                    
                    lock.leave()
                })
                
                lock.wait()
                
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
        let maybeKeypair = newKeypair()
        XCTAssertNotNil(maybeKeypair)
        
        if let new1stKeypair = maybeKeypair
        {
            XCTAssertEqual(new1stKeypair.publicKey.count, publicKeyLength)
            XCTAssertEqual(new1stKeypair.representative.count, representativeLength)
            
            // Do it all again!
            
            let maybe2ndKeypair = newKeypair()
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
        let clientHandshake = ClientHandshake(certString: certString, sessionKey: sessionKey)
        
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
