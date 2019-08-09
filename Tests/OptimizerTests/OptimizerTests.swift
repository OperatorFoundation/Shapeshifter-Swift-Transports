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
        
        let connectionFactory = OptimizerConnectionFactory(possibleTransports: possibleTransports, strategy: ChooseFirst())

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
        
        let connectionFactory = OptimizerConnectionFactory(possibleTransports: possibleTransports, strategy: ChooseRandom())
        
        XCTAssert(connectionFactory != nil)
        
        let possibleConnection = connectionFactory!.connect(using: .tcp)
        
        XCTAssert(possibleConnection != nil)
    }

}
