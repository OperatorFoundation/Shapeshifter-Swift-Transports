//
//  ReplicantTests.swift
//  ReplicantTests
//
//  Created by Adelita Schule on 11/21/18.
//

import XCTest

@testable import Replicant

import Network
import ReplicantSwift

class ReplicantTests: XCTestCase
{

    override func setUp()
    {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    func testConnection()
    {
        let chunkSize: UInt16 = 2000
        let chunkTimeout: Int = 1000
        let aesOverheadSize = 113
        let unencryptedChunkSize = chunkSize - UInt16(aesOverheadSize + 2)
        let testIPString = "192.168.1.72"
        let testPort: UInt16 = 1234
        
        guard let serverPublicKey = Data(base64Encoded: "BL7+Vd087+p/roRp6jSzIWzG3qXhk2S4aefLcYjwRtxGanWUoeoIWmMkAHfiF11vA9d6rhiSjPDL0WFGiSr/Et+wwG7gOrLf8yovmtgSJlooqa7lcMtipTxegPAYtd5yZg==")
            else
        {
            print("Unable to get base64 encoded key from the provided string.")
            XCTFail()
            return
        }
        
        let connected = expectation(description: "Connection callback called")
        let sent = expectation(description: "TCP data sent")
        
        let host = NWEndpoint.Host(testIPString)
        guard let port = NWEndpoint.Port(rawValue: testPort)
            else
        {
            print("\nUnable to initialize port.\n")
            XCTFail()
            return
        }
        
        // Make a Client Connection
        guard let replicantClientConfig = ReplicantConfig(serverPublicKey: serverPublicKey, chunkSize: chunkSize, chunkTimeout: chunkTimeout, toneBurst: nil)
            else
        {
            print("\nUnable to create ReplicantClient config.\n")
            XCTFail()
            return
        }
        
        let clientConnectionFactory = ReplicantConnectionFactory(host: host, port: port, config: replicantClientConfig)
        guard var clientConnection = clientConnectionFactory.connect(using: .tcp)
            else
        {
            XCTFail()
            return
        }
        
        clientConnection.stateUpdateHandler =
        {
            state in
            
            switch state
            {
            case NWConnection.State.ready:
                print("\nConnected state ready\n")
                connected.fulfill()
//                clientConnection.send(content: Data(repeating: 0x0A, count: Int(unencryptedChunkSize+500)), contentContext: NWConnection.ContentContext.defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
//                {
//                    (maybeError) in
//                    
//                    if let error = maybeError
//                    {
//                        print("\nreceived an error on client connection send: \(error)\n")
//                        XCTFail()
//                        return
//                    }
//                    
//                    sent.fulfill()
//                }))
            default:
                print("\nReceived a state other than ready: \(state)\n")
                return
            }
        }
        
        clientConnection.start(queue: .global())
        
        let godot = expectation(description: "forever")
        wait(for: [connected, sent, godot], timeout: 3000)
    }

}
