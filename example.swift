//
//  example.swift
//  Shapeshifter-Swift-TransportsPackageDescription
//
//  Created by Mafalda on 9/16/19.
//

import Foundation
import Datable
import Protean
import ProteanSwift
import Optimizer
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Network
#elseif os(Linux)
import NetworkLinux
#endif


/// This is example code to help illustrate how to use the transports provided in this library.
/// This is an ongoing work in progress :)

// MARK: Protean

func exampleSequenceConfig() -> ByteSequenceShaper.Config?
{
    let sequence = Data(string: "OH HELLO")
    
    guard let sequenceModel = ByteSequenceShaper.SequenceModel(index: 0, offset: 0, sequence: sequence, length: 256)
        else
    {
        return nil
    }
    
    let sequenceConfig = ByteSequenceShaper.Config(addSequences: [sequenceModel], removeSequences: [sequenceModel])
    
    return sequenceConfig
}

public func exampleEncryptionConfig() -> EncryptionShaper.Config
{
    let bytes = Data(count: 32)
    let encryptionConfig = EncryptionShaper.Config(key: bytes)
    
    return encryptionConfig
}

public func exampleHeaderConfig() -> HeaderShaper.Config
{
    // Creates a sample (non-random) config, suitable for testing.
    let header = Data([139, 210, 37])
    let headerConfig = HeaderShaper.Config(addHeader: header, removHeader: header)
    
    return headerConfig
}

func proteanExample()
{
    let ipv4Address = IPv4Address("10.10.10.10")!
    let portUInt = UInt16("7007")!
    let port = NWEndpoint.Port(rawValue: portUInt)!
    let host = NWEndpoint.Host.ipv4(ipv4Address)
    
    // Create a Protean config using your chosen sequence, encryption, and header
    let proteanConfig = Protean.Config(
        byteSequenceConfig: exampleSequenceConfig(),
        encryptionConfig: exampleEncryptionConfig(),
        headerConfig: exampleHeaderConfig())
    
    // Create the connection factory providing your config and the desires IP and port
    let proteanConnectionFactory = ProteanConnectionFactory(host: host, port: port, config: proteanConfig)
    
    // Create a connection using the Protean connection factory
    guard var connection = proteanConnectionFactory.connect
    else
    {
        print("Failed to create a Protean connection object.")
        return
    }
    
    // Set up your state update handler.
    connection.stateUpdateHandler =
    {
        (newState) in
        
        switch newState
        {
        case .ready:
            print("Connection is read")
            connected1.fulfill()
            
        case .failed(let error):
            print("Connection Failed")
            print("Failure Error: \(error.localizedDescription)\n")
            connected1.fulfill()
            
        default:
            print("Connection Other State: \(newState)")
        }
    }
    
    // Tell the connection to start.
    connection.start(queue: DispatchQueue(label: "TestQueue"))
}

// MARK: Optimizer

/// This is an example of creating and starting a network connection using Optimizer's CoreML Strategy.
/// This example also shows the way to get instances of some of our other transports.
func coreMLStrategyExample()
{
    let ipv4Address = IPv4Address("10.10.10.10")!
    let portUInt = UInt16("7007")!
    let port = NWEndpoint.Port(rawValue: portUInt)!
    let host = NWEndpoint.Host.ipv4(ipv4Address)
    
    let logQueue =  Queue<String>()
    let certString = "examplecertstring"
    let serverPublicKey = Data(base64Encoded: "exampleserverpublickeystring")!
    
    // Create a Protean Transport Instance
    let proteanConfig = Protean.Config(byteSequenceConfig: exampleSequenceConfig(),
                                       encryptionConfig: exampleEncryptionConfig(),
                                       headerConfig: exampleHeaderConfig())
     let proteanTransport = ProteanConnectionFactory(host: host, port: port, config: proteanConfig)
    
    // Create a Replicant transport instance.
    guard let replicantClientConfig = ReplicantConfig(serverPublicKey: serverPublicKey, chunkSize: 2000, chunkTimeout: 1000, toneBurst: nil)
        else
    {
        print("\nUnable to create ReplicantClient config.\n")
        return
    }
    let replicantTransport = ReplicantConnectionFactory(host: host, port: port, config: replicantClientConfig, logQueue: logQueue)
    
    // Create a Wisp transport instance.
    let wispTransport = WispConnectionFactory(host: host, port: port, cert: certString, iatMode: false)
    
    // Create an array with all of the transports that Optimizer should choose from.
    let possibleTransports:[ConnectionFactory] = [wispTransport, replicantTransport, proteanTransport]
    
    // Create an instance of your chosen Strategy using the array of transports
    let strategy = CoreMLStrategy(transports: possibleTransports)
    
    // Create an OptimizerConnectionFactory instance using your Strategy.
    let connectionFactory = OptimizerConnectionFactory(strategy: strategy)
    
    // Create the connection using the OptimizerConnectionFactory instance.
    guard var connection = connectionFactory!.connect(using: .tcp)
        else
    {
        return
    }
    
    // Set up your state update handler.
    connection.stateUpdateHandler =
    {
        (newState) in
        
        switch newState
        {
        case .ready:
            print("Connection is read")
            connected1.fulfill()
            
        case .failed(let error):
            print("Connection Failed")
            print("Failure Error: \(error.localizedDescription)\n")
            connected1.fulfill()
            
        default:
            print("Connection Other State: \(newState)")
        }
    }
    
    // Tell the connection to start.
    connection.start(queue: DispatchQueue(label: "TestQueue"))

}
