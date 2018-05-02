//
//  Shapeshifter_Swift_TransportsTests.swift
//  Shapeshifter-Swift-TransportsTests
//
//  Created by Brandon Wiley on 10/22/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import XCTest
import Foundation
import ShapeshifterTesting

@testable import Meek

class Shapeshifter_Swift_TransportsTests: XCTestCase
{
    let testString = "a\r\n\r\nb"
    let testData = "a\r\n\r\nb".data(using: .ascii)!
    let httpResponse = "HTTP/1.1 200 Created\r\nLocation: http://localhost/objectserver/restapi/alerts/status/kf/12481%3ANCOMS\r\nCache-Control: no-cache\r\nServer: libnhttpd\r\nDate: Wed Jul 4 15:31:53 2012\r\nConnection: Keep-Alive\r\nContent-Type: application/json;charset=UTF-8\r\nContent-Length: 304\r\n\r\n{\"entry\": {\"affectedRows\": 1,\"keyField\": \"12481%3ANCOMS\",\"uri\": \"http://localhost/objectserver/restapi/alerts/status/kf/12481%3ANCOMS\"}}"
    
    func testFindEmptyLineIndex()
    {
        let maybeTestMeek: MeekTCPConnection? = MeekTCPConnection(testDate: Date())
        XCTAssertNotNil(maybeTestMeek)
        guard let testMeek = maybeTestMeek else {
            return
        }

        // FIXME - needs expectation to deal with async callback
        testMeek.observeState
        {
            (state, maybeError) in
            
            XCTAssertNil(maybeError)
        }
        
        let maybeIndex = testMeek.findEmptyLineIndex(data: testData)
        XCTAssertNotNil(maybeIndex)
        
        if let emptyLineIndex = maybeIndex
        {
            XCTAssertEqual(emptyLineIndex, 2)
        }
    }
    
    func testSplitOnBlankLine()
    {
        let maybeTestMeek: MeekTCPConnection? = MeekTCPConnection(testDate: Date())
        XCTAssertNotNil(maybeTestMeek)
        guard let testMeek = maybeTestMeek else {
            return
        }
        
        // FIXME - needs expectation to deal with async callback
        testMeek.observeState
            {
                (state, maybeError) in
                
                XCTAssertNil(maybeError)
        }

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
        let maybeTestMeek: MeekTCPConnection? = MeekTCPConnection(testDate: Date())
        XCTAssertNotNil(maybeTestMeek)
        guard let testMeek = maybeTestMeek else {
            return
        }
        
        // FIXME - needs expectation to deal with async callback
        testMeek.observeState
            {
                (state, maybeError) in
                
                XCTAssertNil(maybeError)
        }

        let maybeSessionID = testMeek.generateSessionID()
        XCTAssertNotNil(maybeSessionID)
        if let sessionID = maybeSessionID
        {
            XCTAssertTrue(sessionID.count == 32)
        }
    }
    
    func testGetStatusCode()
    {
        let maybeTestMeek: MeekTCPConnection? = MeekTCPConnection(testDate: Date())
        XCTAssertNotNil(maybeTestMeek)
        guard let testMeek = maybeTestMeek else {
            return
        }
        
        // FIXME - needs expectation to deal with async callback
        testMeek.observeState
            {
                (state, maybeError) in
                
                XCTAssertNil(maybeError)
        }

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
//        let expectation = XCTestExpectation(description: "Connection test.")
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
//                XCTAssertNotNil(maybeData)
//                expectation.fulfill()
//                
//                if let data = maybeData
//                {
//                    print("Received data from http get \(data as NSData) 😎")
//                }
//                else if let error = maybeError
//                {
//                    print("Failed to receive a response from the server. 🤬")
//                    print(error.localizedDescription)
//                }
//                else
//                {
//                    print("Failed to receive a response from the server. No error received. 🤔")
//                }
//
//            })
//        }
//        
//        wait(for: [expectation], timeout: 10.0)
//    }

}

