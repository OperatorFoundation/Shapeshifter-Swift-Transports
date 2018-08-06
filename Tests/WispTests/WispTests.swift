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

@testable import Wisp

class Shapeshifter_WispTests: XCTestCase
{
    let certString = "60RNHBMRrf+aOSPzSj8bD4ASGyyPl0mkaOUAQsAYljSkFB0G8B8m9fGvGJCpOxwoXS1baA"
    let ipAddressString = "166.78.129.122"
    let portString = "1234"
    let endpoint = NWHostEndpoint(hostname: "198.211.106.85", port: "1234")
    
    
    //static let fakeTCPConnection: FakeTCPConnection = createFakeTCPConnection(to: endpoint)
    let secretKeyMaterial = Data(repeating: 0x0A, count: keyMaterialLength)
    static let publicKey = Data(bytes: [139, 210, 37, 89, 10, 47, 113, 85, 13, 53, 118, 181, 28, 8, 202, 146, 220, 206, 224, 143, 24, 159, 235, 136, 173, 194, 120, 171, 201, 54, 238, 76])
    static let privateKey = Data(bytes: [198, 167, 133, 212, 83, 74, 53, 24, 178, 34, 178, 148, 128, 202, 15, 70, 247, 196, 26, 159, 184, 238, 185, 113, 19, 137, 138, 135, 39, 137, 55, 15])
    static let elligatorRepresentative = Data(bytes: [95, 226, 105, 55, 70, 208, 53, 164, 16, 88, 68, 55, 89, 16, 147, 91, 38, 140, 125, 101, 237, 25, 154, 12, 82, 12, 4, 158, 252, 206, 79, 1])
    
    let maxWaitSeconds: Double = 5
    let toEncode = Data(repeating: 0x0A, count: 50)
    let testClientKeypair = Keypair(publicKey: publicKey, privateKey: privateKey, representative: elligatorRepresentative)
    //let wispProtocol = WispProtocol(connection: Shapeshifter_WispTests.fakeTCPConnection as TCPConnection, cert: Shapeshifter_WispTests.certString, iatMode: false)
    
    var wispTCPConnection: WispTCPConnection?
    
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
        let encoded = wispEncoder?.encode(payload: toEncode)
        XCTAssertNotNil(encoded)
        XCTAssertNotEqual(toEncode, encoded)
        
        
        var wispDecoder = WispDecoder(withKey: secretKeyMaterial)
        let lengthData = encoded![0 ..< lengthLength]
        let unobfuscatedLength = wispDecoder?.unobfuscate(obfuscatedLength: lengthData)
        
        XCTAssertEqual(UInt16(toEncode.count + 16), unobfuscatedLength)
    }
    
    func testWispDecoderInit()
    {
        
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
    
    func testFakeTCPConnection()
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
            
            
            connected.fulfill()
            print("CURRENT STATE = \(newState))")
            
            
            //        guard let startCompletion = pendingStartCompletion
            //            else
            //        {
            //            print("pendingStartCompletion is nil?")
            //            return
            //        }
            
            switch newState
            {
            case .ready:
                // Start reading messages from the tunnel connection.
                //self.tunnelConnection?.startHandlingPackets()
                
                // Open the logical flow of packets through the tunnel.
                //let newConnection = ClientTunnelConnection(clientPacketFlow: self.packetFlow)
                print("\n🚀 open() called on tunnel connection  🚀\n")
                connected.fulfill()
                //self.tunnelConnection = newConnection
                //startCompletion(nil)
                
            case .cancelled:
                connected.fulfill()
                print("\n🙅‍♀️  Connection Canceled  🙅‍♀️\n")
                //            self.connection = nil
                //            self.tunnelDidClose()
                //            startCompletion(SimpleTunnelError.cancelled)
                
            case .failed(let error):
                print("\n🐒💨  Connection Failed  🐒💨\n")
                connected.fulfill()
                //            self.closeTunnelWithError(error)
                //            startCompletion(error)
                
            default:
                connected.fulfill()
                print("\n🤷‍♀️  Unexpected State: \(newState))  🤷‍♀️\n")
            }
        }
        
//        fakeTCPConnection.observeState {
//            (state, maybeConnectError) in
//
//            XCTAssertNil(maybeConnectError)
//            guard maybeConnectError == nil else {
//                return
//            }
//
//            switch state {
//                case .connected:
//                    connected.fulfill()
//
//                    fakeTCPConnection.write(Data(repeating: 0x0A, count: 1))
//                    {
//                        (maybeWriteError) in
//
//                        XCTAssertNil(maybeWriteError)
//
//                        guard maybeWriteError == nil else
//                        {
//                            print("\nTest - FakeTCPConnection write failure:")
//                            if let error = maybeWriteError {
//                                print(error.localizedDescription)
//                            }
//
//                            return
//                        }
//
//                        wrote.fulfill()
//                }
//                default:
//                    return
//            }
//        }
//
        waitForExpectations(timeout: maxWaitSeconds)
        { (maybeError) in
            if let error = maybeError
            {
                print("Expectation completed with error: \(error.localizedDescription)")
            }
        }
    }
    
    func testWispTCPConnection()
    {
//        let promise = expectation(description: "Connection state changed.")
//        let maybeConnection = createFakeTCPConnection(to: endpoint)
//        XCTAssertNotNil(maybeConnection)
//        guard let connection = maybeConnection else {
//            return
//        }
//        connection.observeState
//        {
//            (connectionState, maybeError) in
//
//            let maybeWtcpConnection = createWispTCPConnection(connection: connection, cert: self.certString, iatMode: false)
//            XCTAssertNotNil(maybeWtcpConnection)
//        }
    }

//    func testConnectWithHandshake()
//    {
//        let promise = expectation(description: "Connection state changed.")
//        let connection = createFakeTCPConnection(to: endpoint)
//        wispTCPConnection = WispTCPConnection(connection: connection, cert: certString, iatMode: false)
//
//        XCTAssertNotNil(wispTCPConnection)
//        promise.fulfill()
//        _ = wispTCPConnection?.observe(\.state, changeHandler:
//        {
//            (observedConnection, stateChange) in
//
//            print("\n\nWispTCPConnection state Change Observed: \(stateChange) 👯‍♀️")
//            promise.fulfill()
//        })
//
//        waitForExpectations(timeout: maxWaitSeconds)
//        { (maybeError) in
//            if let error = maybeError
//            {
//                print("\nExpectation completed with error: \(error.localizedDescription)\n")
//            }
//        }
//    }
    
//    func testReadLength()
//    {
//        weak var maybExpectation = expectation(description: "Read length test.")
//        //weak var maybExpectation = XCTestExpectation(description: "Read length test.")
//
//        wispTCPConnection!.readLength(serverMinHandshakeLength, completionHandler:
//        { (maybeData, maybeError) in
//
//            guard let expectation = maybExpectation
//            else
//            {
//                print("Expectation is already fulfilled.")
//                return
//            }
//            expectation.fulfill()
//            XCTAssertNotNil(maybeData)
//            print("TEST READ LENGTH COMPLETION")
//
//        })
//
//        waitForExpectations(timeout: maxWaitSeconds)
//        { (maybeError) in
//            if let error = maybeError
//            {
//                print("Expectation completed with error: \(error.localizedDescription)")
//            }
//        }
//    }
    
    func testWrite()
    {
    
    }
    
    //MARK: WispProtocol

    func testProtocolInit()
    {
    }
    
    
    
    func testReadServerHandshake()
    {
        
    }
    
    func testParseServerHandshake()
    {
        
    }
    
    func testGetSeedFromHandshake()
    {
        
    }
    
    func testReadPackets()
    {
        
    }
    
    func testHandlePacketData()
    {
        
    }
    
    func testNtorClientHandshake()
    {
        
    }
    
    func testNtorCommon()
    {
        
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
