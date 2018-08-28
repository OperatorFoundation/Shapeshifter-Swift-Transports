//
//  Rot13TCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/22/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import Transport
import Network

open class Rot13Connection: Connection
{
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    {
        didSet
        {
            network.stateUpdateHandler = stateUpdateHandler
        }
    }
    
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var rotkey: Int = 13
    var network: Connection
    
    public init?(host: NWEndpoint.Host,
         port: NWEndpoint.Port,
         using parameters: NWParameters)
    {
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        guard let newConnection = connectionFactory.connect(parameters)
        else
        {
            return nil
        }
        
        network = newConnection
    }

    public init(connection: Connection, using parameters: NWParameters)
    {
        network = connection
    }
    
    public func start(queue: DispatchQueue)
    {
        network.start(queue: queue)
    }
    
    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        guard let data = content
        else
        {
            print("Received a send command with no content.")
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
            default:
                return
            }
            
            return
        }
        
        guard let encodedContent = encode(data)
        else
        {
            print("Failed to encoded data while attempting Rot13Connection write.")
            switch completion
            {
            case .contentProcessed(let handler):
                handler(NWError.posix(POSIXErrorCode.EBADMSG))
            default:
                return
            }
            
            return
        }
        network.send(content: encodedContent, contentContext: contentContext, isComplete: isComplete, completion: completion)
    }

    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        network.receive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength)
        {
            (maybeData, maybeContext, connectionComplete, maybeError) in
            
            if let encodedData = maybeData
            {
                let decodedData = self.decode(encodedData)
                completion(decodedData, maybeContext, connectionComplete, maybeError)
            }
            else
            {
            completion(maybeData, maybeContext, connectionComplete, maybeError)
            }
        }
    }
    
    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        self.receive(minimumIncompleteLength: 1, maximumLength: 1000000, completion: completion)
    }
    
    public func cancel()
    {
        network.cancel()
        
        if let stateUpdate = self.stateUpdateHandler
        {
            stateUpdate(NWConnection.State.cancelled)
        }
        
        if let viabilityUpdate = self.viabilityUpdateHandler
        {
            viabilityUpdate(false)
        }
    }
    
    func encode(_ data: Data) -> Data?
    {
        var mutdata = data
        mutdata.withUnsafeMutableBytes
            {
                (bytePtr: UnsafeMutablePointer<UInt8>) in
                
                let byteBuffer = UnsafeMutableBufferPointer(start: bytePtr,
                                                            count: data.count/MemoryLayout<Int8>.stride)
                
                for index in 0..<byteBuffer.count
                {
                    byteBuffer[index] = UInt8((Int(byteBuffer[index]) + rotkey) % rotkey)
                }
        }
        
        return mutdata
    }
    
    func decode(_ data: Data) -> Data?
    {
        var mutdata = data
        mutdata.withUnsafeMutableBytes
            {
                (bytePtr: UnsafeMutablePointer<UInt8>) in
                
                let byteBuffer = UnsafeMutableBufferPointer(start: bytePtr,
                                                            count: data.count/MemoryLayout<Int8>.stride)
                
                for index in 0..<byteBuffer.count
                {
                    let byteAtIndex = Int(byteBuffer[index])
                    var rotatedByte = byteAtIndex - rotkey
                    
                    if rotatedByte < 0
                    {
                        rotatedByte += 256
                    }
                    
                    byteBuffer[index] = UInt8(rotatedByte)
                }
        }
        
        return mutdata
    }
    
}
