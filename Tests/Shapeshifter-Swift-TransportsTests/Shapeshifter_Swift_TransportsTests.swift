//
//  Shapeshifter_Swift_TransportsTests.swift
//  Shapeshifter-Swift-TransportsTests
//
//  Created by Brandon Wiley on 10/22/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import XCTest
import Foundation

@testable import Shapeshifter_Swift_Transports

class Shapeshifter_Swift_TransportsTests: XCTestCase
{    
    let testString = "a\r\n\r\nb"
    let testData = "a\r\n\r\nb".data(using: .ascii)!
    let httpResponse = "HTTP/1.1 200 Created\r\nLocation: http://localhost/objectserver/restapi/alerts/status/kf/12481%3ANCOMS\r\nCache-Control: no-cache\r\nServer: libnhttpd\r\nDate: Wed Jul 4 15:31:53 2012\r\nConnection: Keep-Alive\r\nContent-Type: application/json;charset=UTF-8\r\nContent-Length: 304\r\n\r\n{\"entry\": {\"affectedRows\": 1,\"keyField\": \"12481%3ANCOMS\",\"uri\": \"http://localhost/objectserver/restapi/alerts/status/kf/12481%3ANCOMS\"}}"
    var testMeek = MeekTCPConnection(testDate: Date())
    
    override func setUp()
    {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown()
    {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample()
    {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testFindEmptyLineIndex()
    {
        let maybeIndex = testMeek.findEmptyLineIndex(data: testData)
        XCTAssertNotNil(maybeIndex)
        
        if let emptyLineIndex = maybeIndex
        {
            XCTAssertEqual(emptyLineIndex, 2)
        }
    }
    
    func testSplitOnBlankLine()
    {
        let maybeTuple = testMeek.splitOnBlankLine(data: testData)
        
        XCTAssertNotNil(maybeTuple)
        
        if let (first, second) = maybeTuple
        {
            XCTAssertEqual(first, "a")
            XCTAssertEqual(second.first, 98)
        }  
    }
    
    func testSessionIDGeneration()
    {
        let maybeSessionID = testMeek.generateSessionID()
        XCTAssertNotNil(maybeSessionID)
        if let sessionID = maybeSessionID
        {
            print("Tested session ID generation, result:")
            print(sessionID)
            XCTAssertTrue(sessionID.count == 32)
        }
        
    }
    
    func testGetStatusCode()
    {
        let maybeStatusCode = testMeek.getStatusCode(fromHeader: httpResponse)
        XCTAssertNotNil(maybeStatusCode)
        
        if let statusCode = maybeStatusCode
        {
            XCTAssertEqual(statusCode, "200")
        }
    }
    
    /*Test Case '-[Shapeshifter_Swift_TransportsTests.Shapeshifter_Swift_TransportsTests testMeekConnection]' started.
     Could not cast value of type 'Shapeshifter_Swift_Transports.FakePacketTunnelProvider' (0x106973738) to 'NEPacketTunnelProvider' (0x7fffe18adbb0).*/
    
//    func testMeekConnection()
//    {
//        let packetTunnelProvider = FakePacketTunnelProvider()
//        let frontURL = URL(string: "https://www.google.com")
//        let serverURL = URL(string: "https://transport-canary-meek.appspot.com/")
//
//        let meekConnection: MeekTCPConnection = createMeekTCPConnection(provider: packetTunnelProvider, to: frontURL!, serverURL: serverURL!)
//
//        let requestData = "HTTP/1.1 GET /\r\n\r\n".data(using: .ascii)
//
//        meekConnection.write(requestData!)
//        {
//            (maybeError) in
//
//            meekConnection.readMinimumLength(6, maximumLength: 60 + 65536, completionHandler:
//            {
//                (maybeData, maybeError) in
//
//                if let data = maybeData
//                {
//                    print("Received data from http get \(data as NSData)")
//                }
//                else
//                {
//                    print("Failed to receive a response from the server.")
//                }
//
//            })
//        }
//    }
    
    // MARK: Wisp Tests
    
    func testUnpackCertString()
    {
        //Generate (insecure) random data of the correct length for dummy nodeID and publicKey
        let nodeIDBytes = [UInt32](repeating: 0, count: 20).map { _ in arc4random() }
        let testNodeID = Data(bytes: nodeIDBytes, count: 20)
        let publicKeyBytes = [UInt32](repeating: 0, count: 32).map { _ in arc4random() }
        let testPublicKey = Data(bytes: publicKeyBytes, count: 32)
        
        let certData = testNodeID + testPublicKey
        let certString = certData.base64EncodedString()
        
        let maybeCert = unpack(certString: certString)
        XCTAssertNotNil(maybeCert)
        
        if let cert = maybeCert
        {
            XCTAssertEqual(cert.nodeID, testNodeID)
            XCTAssertEqual(cert.publicKey, testPublicKey)
        }
        
    }
    
    func testPerformanceExample()
    {
        // This is an example of a performance test case.
        self.measure
        {
            // Put the code you want to measure the time of here.
        }
    }
    
}
