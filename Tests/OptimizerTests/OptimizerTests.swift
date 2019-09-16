//
//  OptimizerTests.swift
//  OptimizerTests
//
//  Created by Mafalda on 7/17/19.
//

import XCTest
import Network
import Transport
import Protean
import ProteanSwift
import Wisp
import ReplicantSwift
import Replicant
import SwiftQueue
import ExampleTransports

@testable import Optimizer

class OptimizerTests: XCTestCase
{

    func testChooseFirst()
    {
        let ipAddressString = ""
        let portString = "1234"
        let certString = ""
        let proteanConfig = Protean.Config(byteSequenceConfig: sampleSequenceConfig(),
                                           encryptionConfig: sampleEncryptionConfig(),
                                           headerConfig: sampleHeaderConfig())
        
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
        
        //let connected = expectation(description: "Connected to server.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let wispTransport = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false)
        let proteanTransport = ProteanConnectionFactory(host: host, port: port, config: proteanConfig)
        let possibleTransports:[ConnectionFactory] = [wispTransport, proteanTransport]
        let strategy = ChooseFirst(transports: possibleTransports)
        let connectionFactory = OptimizerConnectionFactory(strategy: strategy)
        XCTAssert(connectionFactory != nil)
        
        let possibleConnection = connectionFactory!.connect(using: .tcp)
        XCTAssert(possibleConnection != nil)
    }
    
    func testChooseRandom()
    {
        let ipAddressString = ""
        let portString = "1234"
        let certString = ""
        let proteanConfig = Protean.Config(byteSequenceConfig: sampleSequenceConfig(),
                                           encryptionConfig: sampleEncryptionConfig(),
                                           headerConfig: sampleHeaderConfig())
        
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
        
        //let connected = expectation(description: "Connected to server.")
        let host = NWEndpoint.Host.ipv4(ipv4Address)
        let wispTransport = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false)
        let proteanTransport = ProteanConnectionFactory(host: host, port: port, config: proteanConfig)
        let possibleTransports:[ConnectionFactory] = [wispTransport, proteanTransport]
        let strategy = ChooseRandom(transports: possibleTransports)
        let connectionFactory = OptimizerConnectionFactory(strategy: strategy)
        XCTAssert(connectionFactory != nil)
        
        let possibleConnection = connectionFactory!.connect(using: .tcp)
        XCTAssert(possibleConnection != nil)
    }

    func testCoreMLStrategy()
    {
        let ipAddressString = "10.10.10.10"
        let portString = "2222"
        
        let logQueue =  Queue<String>()
        let certString = "bD4ASGyyPl0mkaOUm9fGvGJCpOxwoXS1baAAQsAYljSkF60RNHBMRrf+aOSPzSj8B0G8B8"
        
        guard let serverPublicKey = Data(base64Encoded: "3qXWmMkAHfiF11vA9d6rhiSjPBL7+Vd087+p/roRp6jSzIWzhk2S4aefLcYjwRtxGanWUoeoIGDL0WFGiSr/Et+wwG7gOrLf8yovmtgSJlooqa7lcMtipTxegPAYtd5yZg==")
            else
        {
            print("Unable to get base64 encoded key from the provided string.")
            XCTFail()
            return
        }
        
        let proteanConfig = Protean.Config(byteSequenceConfig: sampleSequenceConfig(),
                                           encryptionConfig: sampleEncryptionConfig(),
                                           headerConfig: sampleHeaderConfig())
        guard let replicantClientConfig = ReplicantConfig(serverPublicKey: serverPublicKey, chunkSize: 2000, chunkTimeout: 1000, toneBurst: nil)
            else
        {
            print("\nUnable to create ReplicantClient config.\n")
            XCTFail()
            return
        }
        
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
        let wispTransport = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false)
        let replicantTransport = ReplicantConnectionFactory(host: host, port: port, config: replicantClientConfig, logQueue: logQueue)
        let proteanTransport = ProteanConnectionFactory(host: host, port: port, config: proteanConfig)
        let passthroughTransport = PassthroughConnectionFactory(host: host, port: port)
        let rot13Transport = Rot13ConnectionFactory(host: host, port: port)
        
        let possibleTransports:[ConnectionFactory] = [passthroughTransport, rot13Transport, wispTransport, replicantTransport, proteanTransport]
        let strategy = CoreMLStrategy(transports: possibleTransports)
        
        let connected1 = expectation(description: "Connected 1.")
        let connectionFactory1 = OptimizerConnectionFactory(strategy: strategy)
        guard var connection1 = connectionFactory1!.connect(using: .tcp)
            else
        {
            XCTFail()
            return
        }
        
        connection1.stateUpdateHandler =
        {
            (newState) in
            
            switch newState
            {
            case .ready:
                print("\n🚀 Connection 1 is ready  🚀\n")
                connected1.fulfill()
                
            case .failed(let error):
                print("\n🐒💨  Connection 1 Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                connected1.fulfill()
                
            default:
                print("\n🤷‍♀️ Connection 1  Other State: \(newState)  🤷‍♀️\n")
            }
        }
        
        connection1.start(queue: DispatchQueue(label: "TestQueue"))
        
        let connected2 = expectation(description: "Connected 2.")
        let connectionFactory2 = OptimizerConnectionFactory(strategy: strategy)
        guard var connection2 = connectionFactory2!.connect(using: .tcp)
        else
        {
            XCTFail()
            return
        }
        
        connection2.stateUpdateHandler =
        {
            (newState) in
            
            switch newState
            {
            case .ready:
                print("\n🚀 Connection 2 is ready  🚀\n")
                connected2.fulfill()
                
            case .failed(let error):
                print("\n🐒💨  Connection 2 Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                connected2.fulfill()
                
            default:
                print("\n🤷‍♀️  Connection 2 Other State: \(newState))  🤷‍♀️\n")
            }
        }
        
        connection2.start(queue: DispatchQueue(label: "TestQueue"))
        
        let connected3 = expectation(description: "Connected 3.")
        let connectionFactory3 = OptimizerConnectionFactory(strategy: strategy)
        guard var connection3 = connectionFactory3!.connect(using: .tcp)
        else
        {
            XCTFail()
            return
        }
        
        connection3.stateUpdateHandler =
        {
            (newState) in
            
            switch newState
            {
            case .ready:
                print("\n🚀 Connection 3 is ready  🚀\n")
                connected3.fulfill()
                
            case .failed(let error):
                print("\n🐒💨  Connection 3 Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                connected3.fulfill()
                
            default:
                print("\n🤷‍♀️  Connection 3 Other State: \(newState))  🤷‍♀️\n")
            }
        }
        
        connection3.start(queue: DispatchQueue(label: "TestQueue"))
        
        let connected4 = expectation(description: "Connected 4.")
        let connectionFactory4 = OptimizerConnectionFactory(strategy: strategy)
        guard var connection4 = connectionFactory4!.connect(using: .tcp)
            else
        {
            XCTFail()
            return
        }
        
        connection4.stateUpdateHandler =
        {
            (newState) in
            
            switch newState
            {
            case .ready:
                print("\n🚀 Connection 4 is ready  🚀\n")
                connected4.fulfill()
                
            case .failed(let error):
                print("\n🐒💨  Connection 4 Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                connected4.fulfill()
                
            default:
                print("\n🤷‍♀️  Connection 4 Other State: \(newState))  🤷‍♀️\n")
                }
        }
        
        connection4.start(queue: DispatchQueue(label: "TestQueue"))
        
        let connected5 = expectation(description: "Connected 5.")
        let connectionFactory5 = OptimizerConnectionFactory(strategy: strategy)
        guard var connection5 = connectionFactory5!.connect(using: .tcp)
            else
        {
            XCTFail()
            return
        }
        
        connection5.stateUpdateHandler =
        {
            (newState) in
            
            switch newState
            {
            case .ready:
                print("\n🚀 Connection 5 is ready  🚀\n")
                connected5.fulfill()
                
            case .failed(let error):
                print("\n🐒💨  Connection 5 Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                connected5.fulfill()
                
            default:
                print("\n🤷‍♀️  Connection 5 Other State: \(newState))  🤷‍♀️\n")
            }
        }
        
        connection5.start(queue: DispatchQueue(label: "TestQueue"))
        
        let connected6 = expectation(description: "Connected 6.")
        let connectionFactory6 = OptimizerConnectionFactory(strategy: strategy)
        guard var connection6 = connectionFactory6!.connect(using: .tcp)
            else
        {
            XCTFail()
            return
        }
        
        connection6.stateUpdateHandler =
        {
            (newState) in
            
            switch newState
            {
            case .ready:
                print("\n🚀 Connection 6 is ready  🚀\n")
                connected6.fulfill()
                
            case .failed(let error):
                print("\n🐒💨  Connection 6 Failed  🐒💨")
                print("Failure Error: \(error.localizedDescription)\n")
                connected6.fulfill()
                
            default:
                print("\n🤷‍♀️  Connection 6 Other State: \(newState))  🤷‍♀️\n")
            }
        }
        
        connection6.start(queue: DispatchQueue(label: "TestQueue"))
        
        wait(for: [connected1, connected2, connected3, connected4, connected5, connected6], timeout: 300)
    }
}
