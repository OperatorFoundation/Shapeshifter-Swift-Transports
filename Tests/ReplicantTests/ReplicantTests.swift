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
import SwiftQueue
import CryptoKit

class ReplicantTests: XCTestCase
{

    override func setUp()
    {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    func testEmptyConfigConnection()
    {
        let testIPString = "127.0.0.1"
        let testPort: UInt16 = 1234
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
        guard let replicantClientConfig = ReplicantConfig(serverPublicKey: serverPublicKey.x963Representation, chunkSize: chunkSize, chunkTimeout: chunkTimeout, toneBurst: nil)
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
            default:
                print("\nReceived a state other than ready: \(state)\n")
                return
            }
        }
        
        clientConnection.start(queue: .global())
        
        let godot = expectation(description: "forever")
        wait(for: [connected, sent, godot], timeout: 3000)
    }

    func testConnection()
    {
        let chunkSize: UInt16 = 2000
        let chunkTimeout: Int = 1000
        // let aesOverheadSize = 113
        // let unencryptedChunkSize = chunkSize - UInt16(aesOverheadSize + 2)
        let testIPString = "127.0.0.1"
        let testPort: UInt16 = 1234
        let serverPublicKey = P256.KeyAgreement.PrivateKey().publicKey
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
        guard let replicantClientConfig = ReplicantConfig(serverPublicKey: serverPublicKey.x963Representation, chunkSize: chunkSize, chunkTimeout: chunkTimeout, toneBurst: nil)
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
