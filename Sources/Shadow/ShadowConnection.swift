//
//  ShadowConnection.swift
//  Shadow
//
//  Created by Mafalda on 8/3/20.
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

import CryptoKit
import Foundation
import Logging
import Chord
import Datable
import Transport
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Network
#elseif os(Linux)
import NetworkLinux
#endif


open class ShadowConnection: Connection
{
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var log: Logger
    public var config: ShadowConfig
    
    let salt: Data
    let encryptingCipher: Cipher
    var decryptingCipher: Cipher?
    var network: Connection
    var handshakeNeeded = true
    
    public convenience init?(host: NWEndpoint.Host,
                             port: NWEndpoint.Port,
                             parameters: NWParameters,
                             config: ShadowConfig,
                             logger: Logger)
    {
        let connectionFactory = NetworkConnectionFactory(host: host, port: port)
        guard let newConnection = connectionFactory.connect(using: parameters)
        else
        {
            return nil
        }
        
        self.init(connection: newConnection, parameters: parameters, config: config, logger: logger)
    }

    public init?(connection: Connection, parameters: NWParameters, config: ShadowConfig, logger: Logger)
    {
        guard let actualSalt = Cipher.createSalt()
            else
        {
            return nil
        }
        
        guard let eCipher = Cipher(config: config, salt: actualSalt, logger: logger)
            else { return nil }
        
        
        self.salt = actualSalt
        self.encryptingCipher = eCipher
        self.network = connection
        self.log = logger
        self.config = config
        
        network.stateUpdateHandler = networkStateUpdate
    }
    
    // MARK: Connection Protocol
    
    public func start(queue: DispatchQueue)
    {
        
        network.start(queue: queue)
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
    
    // Fixme: Handling of guard failures mirror what Replicant does, questions about completion handling
    
    /// Gets content and encrypts it before passing it along to the network
    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        guard let someData = content
            else
        {
            log.debug("Shadow connection received a send command with no content.")
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
                return
            default:
                return
            }
        }
        
        guard let encrypted = encryptingCipher.pack(plaintext: someData)
            else
        {
            log.error("Failed to encrypt shadow send content.")
            return
        }
        
        network.send(content: encrypted,
                     contentContext: contentContext,
                     isComplete: isComplete,
                     completion: completion)
    }
    
    // Decrypts the received content before passing it along
    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        self.receive(minimumIncompleteLength: 1, maximumLength: Cipher.maxPayloadSize, completion: completion)
    }
    
    
    // TODO: Introduce buffer to honor the requested read size from the application
    // Decrypts the received content before passing it along
    public func receive(minimumIncompleteLength: Int,
                        maximumLength: Int,
                        completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        // Get our encrypted length first
        let encryptedLengthSize = Cipher.lengthSize + Cipher.tagSize
        network.receive(minimumIncompleteLength: encryptedLengthSize, maximumLength: encryptedLengthSize)
        {
            (maybeData, maybeContext, connectionComplete, maybeError) in
            
            // Something went wrong
            if let error = maybeError
            {
                self.log.error("Shadow receive called, but we got an error: \(error)")
                completion(maybeData, maybeContext, connectionComplete, error)
                return
            }
            
            // Nothing to decrypt
            guard let someData = maybeData
                else
            {
                self.log.debug("Shadow receive called, but there was no data.")
                completion(nil, maybeContext, connectionComplete, maybeError)
                return
            }
            
            guard let dCipher = self.decryptingCipher
            else
            {
                self.log.error("Unable to decrypt received data. Decrypting cipher is nil.")
                completion(nil, maybeContext, connectionComplete, NWError.posix(POSIXErrorCode.EFAULT))
                return
            }
            
            guard let lengthData = dCipher.unpack(encrypted: someData, expectedCiphertextLength: Cipher.lengthSize)
            else
            {
                completion(maybeData, maybeContext, connectionComplete, NWError.posix(POSIXErrorCode.EINVAL))
                return
            }
            
            DatableConfig.endianess = .big
            
            guard let lengthUInt16 = lengthData.uint16
            else
            {
                self.log.error("Failed to get encrypted data's expected length. Length data could not be converted to UInt16")
                completion(maybeData, maybeContext, connectionComplete, NWError.posix(POSIXErrorCode.EINVAL))
                return
            }
            
            // Read data of payloadLength + tagSize
            let payloadLength = Int(lengthUInt16)
            let expectedLength = payloadLength + Cipher.tagSize
            
            self.network.receive(minimumIncompleteLength: expectedLength, maximumLength: expectedLength)
            {
                (maybeData, maybeContext, connectionComplete, maybeError) in
                
                self.shadowReceive(payloadLength: payloadLength, maybeData: maybeData, maybeContext: maybeContext, connectionComplete: connectionComplete, maybeError: maybeError, completion: completion)
            }
        }
    }
    
    func shadowReceive(payloadLength: Int,
                       maybeData: Data?,
                       maybeContext: NWConnection.ContentContext?,
                       connectionComplete: Bool,
                       maybeError: NWError?,
                       completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        // Something went wrong
        if let error = maybeError
        {
            self.log.error("Shadow receive called, but we got an error: \(error)")
            completion(maybeData, maybeContext, connectionComplete, error)
            return
        }
        
        // Nothing to decrypt
        guard let someData = maybeData
            else
        {
            self.log.debug("Shadow receive called, but there was no data.")
            completion(nil, maybeContext, connectionComplete, maybeError)
            return
        }
        
        guard let dCipher = self.decryptingCipher
        else
        {
            self.log.error("Unable to decrypt received data. Decrypting cipher is nil.")
            completion(nil, maybeContext, connectionComplete, NWError.posix(POSIXErrorCode.EFAULT))
            return
        }
        
        // Attempt tp decrypt the data we received before passing it along
        guard let decrypted = dCipher.unpack(encrypted: someData, expectedCiphertextLength: payloadLength)
            else
        {
            self.log.error("Shadow failed to decrypt received data.")
            completion(someData, maybeContext, connectionComplete, NWError.posix(POSIXErrorCode.EBADMSG))
            return
        }
        
        completion(decrypted, maybeContext, connectionComplete, maybeError)
    }
    
    // End of Connection Protocol
    
    func networkStateUpdate(networkState: NWConnection.State)
    {
        switch networkState
        {
        case .ready:
            guard handshakeNeeded
                else { return }
            handshakeNeeded = false
            handshake()
        case .cancelled:
            if let actualStateupdateHandler = stateUpdateHandler
            {
                actualStateupdateHandler(.cancelled)
            }
            
            if let actualViabilityHandler = viabilityUpdateHandler
            {
                actualViabilityHandler(false)
            }
        case .failed(let networkError):
            if let actualStateupdateHandler = stateUpdateHandler
            {
                actualStateupdateHandler(.failed(networkError))
            }
            
            if let actualViabilityHandler = viabilityUpdateHandler
            {
                actualViabilityHandler(false)
            }
        default:
            guard let actualStateUpdateHandler = self.stateUpdateHandler
                else { return }
            actualStateUpdateHandler(networkState)
        }
    }
    
    func handshake()
    {
        let saltSent = Synchronizer.sync(sendSalt)
        let saltReceived = Synchronizer.sync(receiveSalt)
        
        if saltSent, saltReceived
        {
            if let actualStateUpdateHandler = self.stateUpdateHandler
            {
                actualStateUpdateHandler(.ready)
            }
            
            if let actualViabilityUpdateHandler = self.viabilityUpdateHandler
            {
                actualViabilityUpdateHandler(true)
            }
        }
        else
        {
            self.network.cancel()
            
            if let actualStateUpdateHandler = self.stateUpdateHandler
            {
                actualStateUpdateHandler(.cancelled)
            }
            
            if let actualViabilityUpdateHandler = self.viabilityUpdateHandler
            {
                actualViabilityUpdateHandler(false)
            }
        }
    }
    
    func sendSalt(completion: @escaping (Bool) -> Void)
    {
        print("Sending Salt : \(salt[0]), \(salt[31])")
        network.send(content: salt, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
        {
            (maybeError) in
            
            if let sendError = maybeError
            {
                self.log.error("Received an error when sending shadow handshake: \(sendError)")
                
                completion(false)
                return
            }
            else
            {
                completion(true)
                return
            }
        }))
    }
    
    func receiveSalt(completion: @escaping (Bool) -> Void)
    {
        network.receive(minimumIncompleteLength: salt.count, maximumLength: salt.count)
        {
            (maybeSalt, _, _, maybeError) in
            
            if let saltError = maybeError
            {
                self.log.error("Error receiving salt from the server: \(saltError)")
                completion(false)
                return
            }
            
            if let serverSalt = maybeSalt
            {
                self.log.debug("Received salt from the server: \(serverSalt.array)")
                
                guard serverSalt.count == self.salt.count
                    else
                {
                    self.log.error("Received a salt with the wrong size. \nGot \(serverSalt.count), expected \(self.salt.count)")
                    completion(false)
                    return
                }
                
                guard let dCipher = Cipher(config: self.config, salt: serverSalt, logger: self.log)
                else
                {
                    completion(false)
                    return
                }
                
                self.decryptingCipher = dCipher
                
                completion(true)
                return
            }
        }
    }
    
    func sendAddress()
    {
        let address = AddressReader().createAddr()
        guard let encryptedAddress = encryptingCipher.pack(plaintext: address)
        else
        {
            self.log.error("Failed to encrypt our address. Cancelling connection.")
            self.network.cancel()
            
            if let actualStateUpdateHandler = self.stateUpdateHandler
            {
                actualStateUpdateHandler(.cancelled)
            }
            
            if let actualViabilityUpdateHandler = self.viabilityUpdateHandler
            {
                actualViabilityUpdateHandler(false)
            }
            
            return
        }
        
        print("Sending address: \(encryptedAddress.count)")
        network.send(content: encryptedAddress, contentContext: .defaultMessage, isComplete: false, completion: NWConnection.SendCompletion.contentProcessed(
        {
            (maybeError) in
            
            if let sendError = maybeError
            {
                self.log.error("Received an error when sending shadow handshake: \(sendError)")
                self.network.cancel()
                
                if let actualStateUpdateHandler = self.stateUpdateHandler
                {
                    actualStateUpdateHandler(.cancelled)
                }
                
                if let actualViabilityUpdateHandler = self.viabilityUpdateHandler
                {
                    actualViabilityUpdateHandler(false)
                }
            }
            else
            {
                if let actualStateUpdateHandler = self.stateUpdateHandler
                {
                    actualStateUpdateHandler(.ready)
                }
                
                if let actualViabilityUpdateHandler = self.viabilityUpdateHandler
                {
                    actualViabilityUpdateHandler(true)
                }
            }
        }))
    }
}
