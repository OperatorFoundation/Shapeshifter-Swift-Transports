//
//  Shapeshifter_Swift_TransportsTests.swift
//  Shapeshifter-Swift-TransportsTests
//
//  Created by Brandon Wiley on 10/22/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import XCTest
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
    
    func testPerformanceExample()
    {
        // This is an example of a performance test case.
        self.measure
        {
            // Put the code you want to measure the time of here.
        }
    }
    
}
