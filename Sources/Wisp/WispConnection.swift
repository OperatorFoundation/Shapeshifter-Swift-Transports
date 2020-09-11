//
//  WispConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/30/17.
//  MIT License
//
//  Copyright (c) 2020 Operator Foundation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// The Wisp transport protocol is wire-compatible with the obfs4 transport and can use obfs4 servers as
// well as obfs4 configuration parameters.
//
// Wisp is a new implementaiton of the obfs4 protocol and is not guaranteed to be identical in
// implementation to other obfs4 implementations except when required for over-the-wire compatibility.

import Foundation
import Logging
import Transport
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Network
#elseif os(Linux)
import NetworkLinux
#endif


let certKey = "cert"
let iatKey = "iatMode"

public class WispConnection: Connection
{
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var endpoint: NWEndpoint?
    public var remoteAddress: NWEndpoint?
    public var localAddress: NWEndpoint?
    //public var connectedPath: NWPath?
    public var cert: String
    public var iatMode: Bool
    public var txtRecord: Data?
    public var hasBetterPath = false
    
    let log: Logger
    
    var networkConnection: Connection
    var writeClosed = false
    var wisp: WispProtocol
    var handshakeDone = false

    public init?(host: NWEndpoint.Host,
                 port: NWEndpoint.Port,
                 using parameters: NWParameters,
                 cert: String,
                 iatMode: Bool,
                 logger: Logger)
    {
        self.cert = cert
        self.iatMode = iatMode
        self.log = logger
        
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        guard let newConnection = connectionFactory.connect(using: parameters)
        else
        {
            return nil
        }
        
        networkConnection = newConnection
        
        guard let newWisp = WispProtocol(connection: networkConnection, cert: cert, iatMode: iatMode, logger: logger)
            else
        {
            return nil
        }

        wisp = newWisp
    }
    
    public init?(connection: Connection,
                 using parameters: NWParameters,
                 cert: String,
                 iatMode: Bool,
                 logger: Logger)
    {
        self.networkConnection = connection
        self.cert = cert
        self.iatMode = iatMode
        self.log = logger
        
        guard let newWisp = WispProtocol(connection: connection, cert: cert, iatMode: iatMode, logger: logger)
            else
        {
            return nil
        }
        
        wisp = newWisp
    }
    
    //MARK: Connection Protocol
    
    public func start(queue: DispatchQueue)
    {
        networkConnection.start(queue: queue)
        
        wisp.connectWithHandshake(certString: cert, sessionKey: wisp.sessionKey)
        {
            (maybeError) in
            
            if let error = maybeError
            {
                self.log.error("Error connecting with handshake: \(error)")
                self.handshakeDone = false
                if let stateUpdate = self.stateUpdateHandler
                {
                    stateUpdate(NWConnection.State.failed(NWError.posix(POSIXErrorCode.EAUTH)))
                }
                
                if let viabilityUpdate = self.viabilityUpdateHandler
                {
                    viabilityUpdate(false)
                }
            }
            else
            {
                self.handshakeDone = true
                if let stateUpdate = self.stateUpdateHandler
                {
                    stateUpdate(NWConnection.State.ready)
                }
                
                if let viabilityUpdate = self.viabilityUpdateHandler
                {
                    viabilityUpdate(true)
                }
            }
        }
    }
    
    public func cancel()
    {
        networkConnection.cancel()
        
        if let stateUpdate = self.stateUpdateHandler
        {
            stateUpdate(NWConnection.State.cancelled)
        }
        
        if let viabilityUpdate = self.viabilityUpdateHandler
        {
            viabilityUpdate(false)
        }
    }

    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        log.debug("WISP Send Called")
        
        guard let data = content
        else
        {
            log.error("Received a send command with no content.")
            switch completion
            {
                case .contentProcessed(let handler):
                    handler(nil)
                default:
                    return
            }
            
            return
        }
        
        guard let frame = wisp.encoder?.encode(payload: data)
            else
        {
            log.error("Failed to encoded data while attempting to WispTCPConnection write.")
            switch completion
            {
                case .contentProcessed(let handler):
                    handler(NWError.posix(POSIXErrorCode.EBADMSG))
                default:
                    return
            }
            
            return
        }
        
        let sendCompletion = NWConnection.SendCompletion.contentProcessed
        {
            (maybeError) in
            
            if let error = maybeError
            {
                self.log.error("\(error)")
            }
            
            self.log.debug("\nWisp Received Completion on Network Connection Send.\n")
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
            default:
                self.log.error("\nWisp: an unexpected response was received on network connection send.\n")
                return
            }
        }
        
        networkConnection.send(content: frame,
                               contentContext: contentContext,
                               isComplete: isComplete,
                               completion: sendCompletion)
    }
    
    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        self.receive(minimumIncompleteLength: 1, maximumLength: 1000000, completion: completion)
    }
    
    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        wisp.readPackets(minRead: minimumIncompleteLength, maxRead: maximumLength)
        {
            (maybeDecodedData, maybeError) in
            
            guard maybeError == nil
                else
            {
                
                completion(nil, nil, true, maybeError)
                return
            }
            
            guard let decodedData = maybeDecodedData
                else
            {
                completion(nil, nil, true, nil)
                return
            }
            
            completion(decodedData, nil, false, nil)
        }
    }
        
}
