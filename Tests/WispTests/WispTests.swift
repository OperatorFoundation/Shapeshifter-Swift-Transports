//
//  Shapeshifter_WispTests.swift
//  Shapeshifter-WispTests
//
//  Created by Brandon Wiley on 10/31/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import XCTest
@testable import Wisp

class Shapeshifter_WispTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
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
    
}
