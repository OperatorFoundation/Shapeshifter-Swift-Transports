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
        let ipAddressString = "159.203.158.90"
        let portString = "1234"
        
        guard let serverPublicKey = Data(base64Encoded: "BL7+Vd087+p/roRp6jSzIWzG3qXhk2S4aefLcYjwRtxGanWUoeoIWmMkAHfiF11vA9d6rhiSjPDL0WFGiSr/Et+wwG7gOrLf8yovmtgSJlooqa7lcMtipTxegPAYtd5yZg==")
            else
        {
            print("Unable to get base64 encoded key from the provided string.")
            XCTFail()
            return
        }
        
        let certString = "60RNHBMRrf+aOSPzSj8bD4ASGyyPl0mkaOUAQsAYljSkFB0G8B8m9fGvGJCpOxwoXS1baA"
//        let proteanConfig = Protean.Config(byteSequenceConfig: sampleSequenceConfig(),
//                                           encryptionConfig: sampleEncryptionConfig(),
//                                           headerConfig: sampleHeaderConfig())
        guard let replicantClientConfig = ReplicantConfig(serverPublicKey: serverPublicKey, chunkSize: 2000, chunkTimeout: 1000, toneBurst: nil)
            else
        {
            print("\nUnable to create ReplicantClient config.\n")
            XCTFail()
            return
        }
        let logQueue =  Queue<String>()
        
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
        let replicantTransport = ReplicantConnectionFactory(host: host, port: port, config: replicantClientConfig, logQueue: logQueue)
        //let proteanTransport = ProteanConnectionFactory(host: host, port: port, config: proteanConfig)
        let passthroughTransport = PassthroughConnectionFactory(host: host, port: port)
        let rot13Transport = Rot13ConnectionFactory(host: host, port: port)
        
        let possibleTransports:[ConnectionFactory] = [passthroughTransport, rot13Transport, wispTransport, replicantTransport]
        let strategy = CoreMLStrategy(transports: possibleTransports)
        
        let connectionFactory1 = OptimizerConnectionFactory(strategy: strategy)
        XCTAssert(connectionFactory1 != nil)
        
        let maybeConnection1 = connectionFactory1!.connect(using: .tcp)
        XCTAssert(maybeConnection1 != nil)
        
        let connectionFactory2 = OptimizerConnectionFactory(strategy: strategy)
        let maybeConnection2 = connectionFactory2!.connect(using: .tcp)
        XCTAssert(maybeConnection2 != nil)
        
        let connectionFactory3 = OptimizerConnectionFactory(strategy: strategy)
        let maybeConnection3 = connectionFactory3!.connect(using: .tcp)
        XCTAssert(maybeConnection3 != nil)
        
        let connectionFactory4 = OptimizerConnectionFactory(strategy: strategy)
        let maybeConnection4 = connectionFactory4!.connect(using: .tcp)
        XCTAssert(maybeConnection4 != nil)
        
        let connectionFactory5 = OptimizerConnectionFactory(strategy: strategy)
        let maybeConnection5 = connectionFactory5!.connect(using: .tcp)
        XCTAssert(maybeConnection5 != nil)
    }
}
