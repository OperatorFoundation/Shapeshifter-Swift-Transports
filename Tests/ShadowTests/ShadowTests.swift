//
//  ShadowTests.swift
//  ShadowTests
//
//  Created by Mafalda on 8/3/20.
//

import XCTest
import CryptoKit
import Logging
import Network

import Datable
import SwiftHexTools

@testable import Shadow

class ShadowTests: XCTestCase
{
    let plainText = Data(array: [0, 1, 2, 3, 4])
    
    func testShadowConnection()
    {
        let testIPString = "127.0.0.1"
        let testPort: UInt16 = 1234
        let connected = expectation(description: "Connection callback called")
        //let sent = expectation(description: "TCP data sent")
        
        let host = NWEndpoint.Host(testIPString)
        guard let port = NWEndpoint.Port(rawValue: testPort)
            else
        {
            print("\nUnable to initialize port.\n")
            XCTFail()
            return
        }
        
        let logger = Logger(label: "Shadow Logger")
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        
        let shadowConfig = ShadowConfig(mode: .CHACHA20_IETF_POLY1305, password: "1234")
        
        let shadowFactory = ShadowConnectionFactory(host: host, port: port, config: shadowConfig, logger: logger)
        
        guard var shadowConnection = shadowFactory.connect(using: .tcp)
            else
        {
            XCTFail()
            return
        }
        
        shadowConnection.stateUpdateHandler =
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
        
        shadowConnection.start(queue: .global())
        
        //let godot = expectation(description: "forever")
        wait(for: [connected], timeout: 3000)
    }
    
    func testShadowSend()
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
        
        let logger = Logger(label: "Shadow Logger")
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        
        let shadowConfig = ShadowConfig(mode: .CHACHA20_IETF_POLY1305, password: "1234")
        
        let shadowFactory = ShadowConnectionFactory(host: host, port: port, config: shadowConfig, logger: logger)
        
        guard var shadowConnection = shadowFactory.connect(using: .tcp)
            else
        {
            XCTFail()
            return
        }
        
        shadowConnection.stateUpdateHandler =
        {
            state in
            
            switch state
            {
            case NWConnection.State.ready:
                print("\nConnected state ready\n")
                connected.fulfill()
                
                shadowConnection.send(content: Data("1234"), contentContext: .defaultMessage, isComplete: true, completion: NWConnection.SendCompletion.contentProcessed(
                {
                    (maybeError) in
                    
                    if let sendError = maybeError
                    {
                        print("Send Error: \(sendError)")
                        XCTFail()
                        return
                    }
                    
                    sent.fulfill()
                }))
            default:
                print("\nReceived a state other than ready: \(state)\n")
                return
            }
        }
        
        shadowConnection.start(queue: .global())
        
        let godot = expectation(description: "forever")
        wait(for: [connected, sent, godot], timeout: 3000)
    }
    
    func testShadowReceive()
    {
        let testIPString = "127.0.0.1"
        let testPort: UInt16 = 1234
        let connected = expectation(description: "Connection callback called")
        let sent = expectation(description: "TCP data sent")
        let received = expectation(description: "TCP data received")
        
        let host = NWEndpoint.Host(testIPString)
        guard let port = NWEndpoint.Port(rawValue: testPort)
            else
        {
            print("\nUnable to initialize port.\n")
            XCTFail()
            return
        }
        
        let logger = Logger(label: "Shadow Logger")
        LoggingSystem.bootstrap(StreamLogHandler.standardError)
        
        let shadowConfig = ShadowConfig(mode: .CHACHA20_IETF_POLY1305, password: "1234")
        
        let shadowFactory = ShadowConnectionFactory(host: host, port: port, config: shadowConfig, logger: logger)
        
        guard var shadowConnection = shadowFactory.connect(using: .tcp)
            else
        {
            XCTFail()
            return
        }
        
        shadowConnection.stateUpdateHandler =
        {
            state in
            
            switch state
            {
            case NWConnection.State.ready:
                print("\nConnected state ready\n")
                connected.fulfill()
                
                shadowConnection.send(content: Data("1234"), contentContext: .defaultMessage, isComplete: true, completion: NWConnection.SendCompletion.contentProcessed(
                {
                    (maybeError) in
                    
                    if let sendError = maybeError
                    {
                        print("Send Error: \(sendError)")
                        XCTFail()
                        return
                    }
                    
                    sent.fulfill()
                    
                    shadowConnection.receive
                    {
                        (maybeData, maybeContext, isComplete, maybeReceiveError) in
                        
                        if let receiveError = maybeReceiveError
                        {
                            print("Got a receive error \(receiveError)")
                            XCTFail()
                            return
                        }
                        
                        if let data = maybeData
                        {
                            print("Received data!!")
                            print(data.array)
                            received.fulfill()
                        }
                    }
                }))
            default:
                print("\nReceived a state other than ready: \(state)\n")
                return
            }
        }
        
        shadowConnection.start(queue: .global())
        
        let godot = expectation(description: "forever")
        wait(for: [connected, sent, received, godot], timeout: 3000)
    }
//    func testHKDF()
//    {
//        let correct = Data(base64Encoded: "k7qvG929qzyHVF7D2Bxke78qIxk1A8jk/JKSA7K0V40=")
//        let secret = Data(base64Encoded: "aFkrPPcQtd5QLc5xBuUhazfDQijc3HVXb974bqnSH4c=")
//        let salt = Data(base64Encoded: "rUU438RMMHLlSH0jLMp9FSrFHHuWj4eQw/dq1XQpnJ0=")
//        let info = Data(string: "ss-subkey")
//
//        guard let result = Cipher(config: <#ShadowConfig#>, salt: <#Data#>, logger: <#Logger#>).hkdfSHA1(secret: secret!, salt: salt!, cipherMode: CipherMode.AES_128_GCM)
//        else
//        {
//            XCTFail()
//            return
//        }
//
//        XCTAssertEqual(correct, result)
//    }
//
//    // AES.GCM 128
//    func testAES128()
//    {
//        let nonce = Data(base64Encoded: "GPiavgwl3vKAa6aK")
//        let secret = Data(base64Encoded: "x1wXVJg6pM4ML48HB6YyEA==")
//        let salt = Data(base64Encoded: "AIZClCKlN3LnoNtETQmh31kScJPT3jCt")
//        let info = Data(string: "ss-subkey")
//        let key = Cipher().hkdfSHA1(secret: secret!, salt: salt!, info: info)
//        //let key = Data(base64Encoded: "vru391Vs32PEhzOuiS325A==")
//
//        // Encrypt a thing
//        do
//        {
//            //Seal
//            let encrypted = try AES.GCM.seal(plainText,
//                                             using: SymmetricKey(data: key!),
//                                             nonce: AES.GCM.Nonce(data: nonce!))
//
//
//
//            let correct = Data(base64Encoded: "I2lhGBsa1w45XV9I486z4A3j7oro")
//            XCTAssertEqual(encrypted.combined![12...], correct)
//        }
//        catch let error
//        {
//            print("Error encrypting data: \(error)")
//            XCTFail()
//        }
//    }
//
//    // AES.GCM 192
//    func testAES192()
//    {
//        let nonce = Data(base64Encoded: "9y3YUf37OrbhoESq")
//        let secret = Data(base64Encoded: "zxhocnRVToKo5axoM9ZiCRV8ZwU9zRD9")
//        let salt = Data(base64Encoded: "biPWP0Uk2UI9tJmwjWACwzU5ltViYJvw")
//        let info = Data(string: "ss-subkey")
//        let key = Cipher().hkdfSHA1(secret: secret!, salt: salt!, info: info)
//        //let key = Data(base64Encoded: "mEl7TEjOwbOBvCpwT9fA6xQuJJ5t8EOC")
//
//        // Encrypt a thing
//        do
//        {
//            //Seal
//            let encrypted = try AES.GCM.seal(plainText,
//                                             using: SymmetricKey(data: key!),
//                                             nonce: AES.GCM.Nonce(data: nonce!))
//            let correct = Data(base64Encoded: "NJ2FGAA4h35pvqgHqbpqEEwYPmif")
//
//            XCTAssertEqual(encrypted.combined![12...], correct)
//        }
//        catch let error
//        {
//            print("Error encrypting data: \(error)")
//            XCTFail()
//        }
//    }
//
//    // AES.GCM 256
//    func testAES256()
//    {
//        let nonce = Data(base64Encoded: "MSX/t7/6kgl56xFP")
//        let secret = Data(base64Encoded: "aFkrPPcQtd5QLc5xBuUhazfDQijc3HVXb974bqnSH4c=")
//        let salt = Data(base64Encoded: "rUU438RMMHLlSH0jLMp9FSrFHHuWj4eQw/dq1XQpnJ0=")
//        let info = Data(string: "ss-subkey")
//        let key = Cipher().hkdfSHA1(secret: secret!, salt: salt!, info: info)
//        //let key = Data(base64Encoded: "k7qvG929qzyHVF7D2Bxke78qIxk1A8jk/JKSA7K0V40=")
//
//        // Encrypt a thing
//        do
//        {
//            //Seal
//            let encrypted = try AES.GCM.seal(plainText,
//                                             using: SymmetricKey(data: key!),
//                                             nonce: AES.GCM.Nonce(data: nonce!))
//            let correct = Data(base64Encoded: "6k8tJuPU87yBFrtniSage8SX9xiU")
//
//            XCTAssertEqual(encrypted.combined![12...], correct)
//        }
//        catch let error
//        {
//            print("Error encrypting data: \(error)")
//            XCTFail()
//        }
//    }
//
//    // AES.GCM ChaChaPoly
//    func testChaChaPoly()
//    {
//        let nonce = Data(base64Encoded: "kA3DoGigyGYfF2bj")
//        let secret = Data(base64Encoded: "q2f5hKCwszOLvvsc4g1cMj1gwho1O3dE2ttwTks8haE=")
//        let salt = Data(base64Encoded: "rUU438RMMHLlSH0jLMp9FSrFHHuWj4eQw/dq1XQpnJ0=")
//        let info = Data(string: "ss-subkey")
//        let key = Cipher().hkdfSHA1(secret: secret!, salt: salt!, info: info)
//        //let key = Data(base64Encoded: "mnbqMaGH95dS2jZXaeT9UTszQ0myRcBu1CCjxA+MafY=")
//
//        do
//        {
//            let encrypted = try ChaChaPoly.seal(plainText,
//                                                using: SymmetricKey(data: key!),
//                                                nonce: ChaChaPoly.Nonce(data: nonce!))
//            let correct = Data(base64Encoded: "LJQq3ms5dYIPoN/csclHFuCU1EH0")
//            XCTAssertEqual(encrypted.combined[12...], correct)
//        }
//        catch let error
//        {
//            print("Error encrypting data: \(error)")
//            XCTFail()
//        }
//    }

}
