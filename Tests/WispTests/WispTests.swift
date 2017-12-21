//
//  Shapeshifter_WispTests.swift
//  Shapeshifter-WispTests
//
//  Created by Brandon Wiley on 10/31/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import XCTest
import Sodium
import Elligator
import FakeTCPConnection
import NetworkExtension

@testable import Wisp

class Shapeshifter_WispTests: XCTestCase
{
    
    //MARK: WispCoding
    
    static let keyMaterial = Data(repeating: 0x0A, count: keyMaterialLength)
    
    let toEncode = Data(repeating: 0x0A, count: 50)
    let encodedTestData = Data(bytes: [236, 69, 167, 8, 148, 209, 209, 26, 163, 5, 160, 126, 3, 85, 161, 204, 69, 40, 53, 223, 124, 66, 187, 207, 85, 51, 142, 240, 134, 12, 175, 40, 159, 182, 170, 80, 151, 172, 236, 42, 150, 209, 244, 87, 60, 83, 171, 4, 237, 82, 179, 52, 189, 65, 117, 159, 60, 118, 233, 86, 131, 139, 181, 187, 142, 98, 255, 34])
    var wispEncoder = WispEncoder(withKey: keyMaterial)
    var wispDecoder = WispDecoder(withKey: keyMaterial)
    
    func testWispEncoderInit()
    {
        XCTAssertNotNil(wispEncoder)
        
        if let encoder = wispEncoder
        {
            XCTAssertEqual(encoder.secretBoxKey.count, keyLength)
            XCTAssertEqual(encoder.nonce.counter, 0)
            XCTAssertEqual(encoder.nonce.prefix.count, noncePrefixLength)
            XCTAssertEqual(encoder.drbg.sip.count, 16)
            XCTAssertEqual(encoder.drbg.ofb.count, siphashSize)
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
        
        let expectedOutcome = Data(bytes: [236, 69, 46, 10, 77, 178, 64, 212])
        let nextBlock = wispEncoder!.drbg.nextBlock()
        XCTAssertEqual(nextBlock, expectedOutcome)
    }
    
    func testEncodePayload()
    {
        let encoded = wispEncoder?.encode(payload: toEncode)
        XCTAssertNotNil(encoded)
        XCTAssertNotEqual(toEncode, encoded)
        
        /// Let's discuss obfuscated length <-----------
        print("ToEncode count: \(toEncode.count)")
        print("Encoded count: \(String(describing: encoded?.count))")
    }
    
    func testWispDecoderInit()
    {
        XCTAssertNotNil(wispDecoder)
    }
    
    func testDecodeFramesBuffer()
    {
        let decodedResult = wispDecoder?.decode(framesBuffer: encodedTestData)
        XCTAssertNotNil(decodedResult)
        
//        if decodedResult != nil
//        {
//            switch decodedResult!
//            {
//            case let .success(decodedData, leftovers):
//                XCTAssertEqual(decodedData, toEncode)
//            default:
//                print(decodedResult.debugDescription)
//                XCTFail()
//            }
//        }
        
    }
    
    func testRandomInRange()
    {
        guard let decoder = wispDecoder
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
    let endpoint = NWHostEndpoint(hostname: "MeekServer.com", port: "13374")
    let testTCPConnection = createFakeTCPConnection(to: endpoint)
    let wispTCPConnection = WispTCPConnection(connection: testTCPConnection, cert: certString, iatMode: false)
    
    func testReadMinimumLength()
    {
        
    }
    
    func testReadLength()
    {
        
    }
    
    func testWrite()
    {
    
    }
    
    //MARK: WispProtocol
    let certString = "eGHYXvMVPFm4OtIBn9mxLKeBhZS2rEZSHNPIzC7k/ZbBQv6cCVib1xf/gu8lBR3azOHdWA"
    let publicKey = Data(bytes: [139, 210, 37, 89, 10, 47, 113, 85, 13, 53, 118, 181, 28, 8, 202, 146, 220, 206, 224, 143, 24, 159, 235, 136, 173, 194, 120, 171, 201, 54, 238, 76])
    let privateKey = Data(bytes: [198, 167, 133, 212, 83, 74, 53, 24, 178, 34, 178, 148, 128, 202, 15, 70, 247, 196, 26, 159, 184, 238, 185, 113, 19, 137, 138, 135, 39, 137, 55, 15])
    let elligatorRepresentative = Data(bytes: [95, 226, 105, 55, 70, 208, 53, 164, 16, 88, 68, 55, 89, 16, 147, 91, 38, 140, 125, 101, 237, 25, 154, 12, 82, 12, 4, 158, 252, 206, 79, 1])
    let wispProtocol = WispProtocol(connection: <#T##NWTCPConnection#>, cert: <#T##String#>, iatMode: <#T##Bool#>)
    
    func testProtocolInit()
    {
        
    }
    
    func testConnectWithHandshake()
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
        let sessionKey = Keypair(publicKey: publicKey, privateKey: privateKey, representative: elligatorRepresentative)
        let clientHandshake = ClientHandshake(certString: certString, sessionKey: sessionKey)
        
        // Did we init the handshake?
        XCTAssertNotNil(clientHandshake)
        
        // Is the handshake computed property returning a value?
        XCTAssertNotNil(clientHandshake?.data)
        
        
        if let handshakeData = clientHandshake?.data
        {
            // The first bit of handshake data should be our elligator representative
            let rep = handshakeData[0 ..< representativeLength]
            XCTAssertEqual(rep, elligatorRepresentative)
        }
    }
    
    /// Also tests unpack(certData:) and serverCert(fromString:)
    func testUnpackCertString()
    {
//        //Generate (insecure) random data of the correct length for dummy nodeID and publicKey
//        let nodeIDBytes = [UInt32](repeating: 0, count: 20).map { _ in arc4random() }
//        let testNodeID = Data(bytes: nodeIDBytes, count: 20)
//        let publicKeyBytes = [UInt32](repeating: 0, count: 32).map { _ in arc4random() }
//        let testPublicKey = Data(bytes: publicKeyBytes, count: 32)
//
//        let certData = testNodeID + testPublicKey
//        let certString = certData.base64EncodedString()
        
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
