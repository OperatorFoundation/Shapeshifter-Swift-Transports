//
//  example.swift
//  Shapeshifter-Swift-TransportsPackageDescription
//
//  Created by Mafalda on 9/16/19.
//

import Foundation

/// This is example code to help illustrate how to use the transports provided in this library.
/// This is an ongoing work in progress :)

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
    let proteanConfig = Protean.Config(byteSequenceConfig: sampleSequenceConfig(),
                                       encryptionConfig: sampleEncryptionConfig(),
                                       headerConfig: sampleHeaderConfig())
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
        XCTFail()
        return
    }
    
    // Set up your state update handler.
    connection.stateUpdateHandler =
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
    
    // Tell the connection to start.
    connection.start(queue: DispatchQueue(label: "TestQueue"))

}
