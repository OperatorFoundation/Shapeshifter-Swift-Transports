//
//  ReplicantConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Adelita Schule on 11/21/18.
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

import Foundation
import Logging

import ReplicantSwift
import Transport

#if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
import CryptoKit
import Network
import Transmission
#else
import Crypto
import NetworkLinux
import TransmissionLinux
#endif


open class ReplicantConnection: Transport.Connection
{
    public let aesOverheadSize = 113
    public let payloadLengthOverhead = 2
    public var stateUpdateHandler: ((NWConnection.State) -> Void)?
    public var viabilityUpdateHandler: ((Bool) -> Void)?
    public var config: ReplicantConfig<SilverClientConfig>
    public var replicantClientModel: ReplicantClientModel
    public var log: Logger
    
    var unencryptedChunkSize: UInt16 = 400 // FIXME: unencrypted chunk size for non-polish
    var sendTimer: Timer?
    var networkQueue = DispatchQueue(label: "Replicant Queue")
    var sendBufferQueue = DispatchQueue(label: "SendBuffer Queue")
    var bufferLock = DispatchGroup()
    var decryptedReceiveBuffer: Data
    var sendBuffer: Data
    
    #if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
    var network: Transmission.Connection
    #else
    var network: TransmissionLinux.Connection
    #endif
    
    public convenience init?(host: NWEndpoint.Host,
                 port: NWEndpoint.Port,
                 parameters: NWParameters,
                 config: ReplicantConfig<SilverClientConfig>,
                 logger: Logger)
    {
        logger.debug("Initialized a Replicant Client Connection")
        
        #if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
        guard let newConnection = Transmission.Connection(host: "\(host)", port: Int(port.rawValue))
        else
        {
            logger.error("Failed to create replicant connection. NetworkConnectionFactory.connect returned nil.")
            return nil
        }
        #else
        guard let newConnection = TransmissionLinux.Connection(host: "\(host)", port: Int(port.rawValue))
        else
        {
            logger.error("Failed to create replicant connection. NetworkConnectionFactory.connect returned nil.")
            return nil
        }
        #endif
        
        self.init(connection: newConnection, parameters: parameters, config: config, logger: logger)
    }
    
    #if (os(macOS) || os(iOS) || os(watchOS) || os(tvOS))
    public init?(connection: Transmission.Connection,
                parameters: NWParameters,
                config: ReplicantConfig<SilverClientConfig>,
                logger: Logger)
    {
        let newReplicant = ReplicantClientModel(withConfig: config, logger: logger)
        
        self.network = connection
        self.config = config
        self.replicantClientModel = newReplicant
        self.decryptedReceiveBuffer = Data()
        self.sendBuffer = Data()
        self.log = logger
        
        if let polishConnection = replicantClientModel.polish
        {
            self.unencryptedChunkSize = polishConnection.chunkSize - UInt16(payloadLengthOverhead)
        }
        
        introductions
        {
            (maybeIntroError) in
            
            guard maybeIntroError == nil
                else
            {
                logger.error("Error attempting to meet the server during Replicant Connection Init.")
                return
            }
            
            logger.debug("\nNew Replicant connection is ready. 🎉 \n")
        }
    }
    #else
    public init?(connection: TransmissionLinux.Connection,
                parameters: NWParameters,
                config: ReplicantConfig<SilverClientConfig>,
                logger: Logger)
    {
        let newReplicant = ReplicantClientModel(withConfig: config, logger: logger)
        
        self.network = connection
        self.config = config
        self.replicantClientModel = newReplicant
        self.decryptedReceiveBuffer = Data()
        self.sendBuffer = Data()
        self.log = logger
        
        if let polishConnection = replicantClientModel.polish
        {
            self.unencryptedChunkSize = polishConnection.chunkSize - UInt16(payloadLengthOverhead)
        }
        
        introductions
        {
            (maybeIntroError) in
            
            guard maybeIntroError == nil
                else
            {
                logger.error("Error attempting to meet the server during Replicant Connection Init.")
                return
            }
            
            logger.debug("\nNew Replicant connection is ready. 🎉 \n")
        }
    }
    #endif
    
    public func start(queue: DispatchQueue)
    {
        log.debug("\n🏁 Start called on Replicant connection.")
        
        guard let updateHandler = stateUpdateHandler
        else
        {
            log.info("Called start when there is no stateUpdateHandler.")
            return
        }
        
        updateHandler(.ready)
    }
    
    public func send(content: Data?, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        log.debug("\n💌 Send called on Replicant connection.")
        if let polishConnection = replicantClientModel.polish
        {
            // Lock so that the timer cannot fire and change the buffer. Unlock in the network send() callback.
            bufferLock.enter()
            
            guard let someData = content
                else
            {
                log.error("Received a send command with no content.")
                switch completion
                {
                    case .contentProcessed(let handler):
                        handler(nil)
                        bufferLock.leave()
                        return
                    default:
                        bufferLock.leave()
                        return
                }
            }
            
            self.sendBuffer.append(someData)
            sendBufferChunks(polishConnection: polishConnection, contentContext: contentContext, isComplete: isComplete, completion: completion)
        }
        else // No Polish needed, send the data if it's provided
        {
            guard let someData = content
                else
            {
                log.error("Received a send command with no content.")
                switch completion
                {
                    case .contentProcessed(let handler):
                        handler(nil)
                        bufferLock.leave()
                        return
                    default:
                        bufferLock.leave()
                        return
                }
            }
            
            let written = network.write(data: someData)
            
            switch completion
            {
                case .contentProcessed(let handler):
                    if written { handler(nil) }
                    else { handler(NWError.posix(.EIO)) }
                    return
                default:
                    return
            }
        }
    }
    
    func sendBufferChunks(polishConnection: PolishConnection, contentContext: NWConnection.ContentContext, isComplete: Bool, completion: NWConnection.SendCompletion)
    {
        // Only encrypt and send over network when chunk size is available, leftovers to the buffer
        guard self.sendBuffer.count >= (unencryptedChunkSize)
            else
        {
            log.error("Received a send command with content less than chunk size.")
            switch completion
            {
            case .contentProcessed(let handler):
                handler(nil)
                bufferLock.leave()
                return
            default:
                bufferLock.leave()
                return
            }
        }
        
        let payloadData = self.sendBuffer[0 ..< unencryptedChunkSize]
        let payloadSize = UInt16(unencryptedChunkSize)
        let dataChunk = payloadSize.data + payloadData
        guard let polishedData = polishConnection.polish(inputData: dataChunk)
        else
        {
            log.error("sendBufferChunks: Failed to polish data. Giving up.")
            bufferLock.leave()
            return
        }
        
        // Buffer should only contain unsent data
        self.sendBuffer = self.sendBuffer[unencryptedChunkSize...]
        
        // Turn off the timer
        if self.sendTimer != nil
        {
            self.sendTimer!.invalidate()
            self.sendTimer = nil
        }
        
        // Keep calling network.write if the leftover data is at least chunk size
        guard network.write(data: polishedData)
        else
        {
            self.log.error("Replicant write failed.")
            if self.sendTimer != nil
            {
                self.sendTimer!.invalidate()
                self.sendTimer = nil
            }
            
            switch completion
            {
                case .contentProcessed(let handler):
                    handler(NWError.posix(.EIO))
                    self.bufferLock.leave()
                    return
                default:
                    self.bufferLock.leave()
                    return
            }
        }
        
        if self.sendBuffer.count >= (self.unencryptedChunkSize)
        {
            // Play it again Sam
            self.sendBufferChunks(polishConnection: polishConnection, contentContext: contentContext, isComplete: isComplete, completion: completion)
        }
        else
        {
            // Start the timer
            if self.sendBuffer.count > 0
            {
                self.sendTimer = Timer(timeInterval: TimeInterval(polishConnection.chunkTimeout), repeats: true)
                {
                    (timer) in
                    
                    self.chunkTimeout()
                }
            }
            
            switch completion
            {
                // FIXME: There might be data in the buffer
                case .contentProcessed(let handler):
                    handler(nil)
                    self.bufferLock.leave()
                    return
                default:
                    self.bufferLock.leave()
                    return
            }
        }
    }
    
    public func receive(completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        self.receive(minimumIncompleteLength: 1, maximumLength: 1000000, completion: completion)
    }
    
    public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, NWConnection.ContentContext?, Bool, NWError?) -> Void)
    {
        log.debug("\n🙋‍♀️  Replicant connection receive called.\n")
        
        if let polishConnection = replicantClientModel.polish
        {
            bufferLock.enter()
            
            // Check to see if we have min length data in decrypted buffer before calling network receive. Skip the call if we do.
            if decryptedReceiveBuffer.count >= minimumIncompleteLength
            {
                // Make sure that the slice we get isn't bigger than the available data count or the maximum requested.
                let sliceLength = decryptedReceiveBuffer.count < maximumLength ? decryptedReceiveBuffer.count : maximumLength
                
                // Return the requested amount
                let returnData = self.decryptedReceiveBuffer[0 ..< sliceLength]

                // Remove what was delivered from the buffer
                self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[sliceLength...]
                
                completion(returnData, NWConnection.ContentContext.defaultMessage, false, nil)
                bufferLock.leave()
                return
            }
            else
            {
                // Read ChunkSize amount of data
                // Check to see if we got data, and that it is the right size
                guard let someData = network.read(size: Int(polishConnection.chunkSize)), someData.count == polishConnection.chunkSize
                else
                {
                    self.log.error("\n🙋‍♀️  Read called but no data was receieved.\n")
                    completion(nil, .defaultMessage, false, NWError.posix(.ENODATA))
                    return
                }
                
                let maybeReturnData = self.handleReceivedData(polishConnection: polishConnection, minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength, encryptedData: someData)
                
                completion(maybeReturnData, .defaultMessage, false, nil)
                self.bufferLock.leave()
                return
            }
        }
        else
        {
            // Check to see if we got data
            guard let someData = network.read(size: minimumIncompleteLength)
            else
            {
                self.log.error("\n🙋‍♀️  Read called but no data was receieved.\n")
                completion(nil, .defaultMessage, false, NWError.posix(.ENODATA))
                return
            }
                        
            completion(someData, .defaultMessage, false, nil)
            return
        }
    }
    
    public func cancel()
    {
        // TODO: network.cancel()
        
        if let stateUpdate = self.stateUpdateHandler
        {
            stateUpdate(NWConnection.State.cancelled)
        }
        
        if let viabilityUpdate = self.viabilityUpdateHandler
        {
            viabilityUpdate(false)
        }
    }
    
    /// This takes an optional data and adds it to the buffer before acting on min/max lengths
    func handleReceivedData(polishConnection: PolishConnection, minimumIncompleteLength: Int, maximumLength: Int, encryptedData: Data) -> Data?
    {
        // Try to decrypt the entire contents of the encrypted buffer
        guard let decryptedData = polishConnection.unpolish(polishedData: encryptedData)
        else
        {
            log.error("Unable to decrypt encrypted receive buffer")
            return nil
        }
        
        // The first two bytes simply lets us know the actual size of the payload
        // This helps account for cases when the payload must be smaller than chunk size
        guard let uintPayloadSize = decryptedData[..<payloadLengthOverhead].uint16
            else { return nil }
        let payloadSize = Int(uintPayloadSize)
        let payload = decryptedData[payloadLengthOverhead..<payloadSize]
        
        // Add decrypted data to the decrypted buffer
        self.decryptedReceiveBuffer.append(payload)
        
        // Check to see if the decrypted buffer meets min/max parameters
        guard decryptedReceiveBuffer.count >= minimumIncompleteLength
            else
        {
            // Not enough data return nothing
            return nil
        }
        
        // Make sure that the slice we get isn't bigger than the available data count or the maximum requested.
        let sliceLength = decryptedReceiveBuffer.count < maximumLength ? decryptedReceiveBuffer.count : maximumLength
        
        // Return the requested amount
        let returnData = self.decryptedReceiveBuffer[0 ..< sliceLength]
        
        // Remove what was delivered from the buffer
        self.decryptedReceiveBuffer = self.decryptedReceiveBuffer[sliceLength...]
        
        return returnData
    }
    
    func voightKampffTest(completion: @escaping (Error?) -> Void)
    {
        // Tone Burst
        if var toneBurst = self.replicantClientModel.toneBurst
        {
            toneBurst.play(connection: self)
            {
                maybeError in
                
                completion(maybeError)
            }
        }
        else
        {
            completion(nil)
        }
    }
    
    func introductions(completion: @escaping (Error?) -> Void)
    {
        voightKampffTest
        {
            (maybeVKError) in
            
            guard maybeVKError == nil
                else
            {
                self.stateUpdateHandler?(NWConnection.State.cancelled)
                self.log.error("Toneburst error: \(maybeVKError!)")
                completion(maybeVKError)
                return
            }
            
            if var polishConnection = self.replicantClientModel.polish
            {
                polishConnection.handshake(connection: self)
                {
                    (maybeHandshakeError) in
                    
                    if let handshakeError = maybeHandshakeError
                    {
                        self.log.error("Received a handshake error: \(handshakeError)")
                        self.stateUpdateHandler?(NWConnection.State.cancelled)
                        completion(handshakeError)
                        return
                    }
                    else
                    {
                        self.log.debug("\n🤝  Client successfully completed handshake. 👏👏👏👏\n")
                        self.stateUpdateHandler?(NWConnection.State.ready)
                        completion(nil)
                    }
                }
            }
            else
            {
                self.log.debug("No need to perform the Replicant handshake with the server, the Polish connection is nil.")
                completion(nil)
            }
        }
    }
    
    @objc func chunkTimeout()
    {
        // Lock so that send isn't called while we're working
        bufferLock.enter()
        
        self.sendTimer = nil
        
        // Double check the buffer to be sure that there is still data in there.
        self.log.debug("\n⏰  Chunk Timeout Reached\n  ⏰")
        
        let payloadSize = sendBuffer.count
        
        if let polishConnection = replicantClientModel.polish
        {
            guard payloadSize > 0, payloadSize < polishConnection.chunkSize
            else
            {
                bufferLock.leave()
                return
            }
            
            let payloadData = self.sendBuffer
            let paddingSize = Int(unencryptedChunkSize) - payloadSize
            let padding = Data(repeating: 0, count: paddingSize)
            let dataChunk = UInt16(payloadSize).data + payloadData + padding
            let maybeEncryptedData = polishConnection.polish(inputData: dataChunk)
            
            // Buffer should only contain unsent data
            self.sendBuffer = Data()
            
            // Keep calling network.send if the leftover data is at least chunk size
            if let encryptedData = maybeEncryptedData
            {
                guard network.write(data: encryptedData)
                else
                {
                    self.log.error("Replicant Connection write failed.")
                    self.bufferLock.leave()
                    return
                }
                
                self.bufferLock.leave()
                return
            }
        }
        else // Replicant without polish
        {
            guard payloadSize > 0
            else
            {
                bufferLock.leave()
                return
            }
            
            let payloadData = self.sendBuffer
            let paddingSize = Int(unencryptedChunkSize) - payloadSize
            let padding = Data(repeating: 0, count: paddingSize)
            let dataChunk = UInt16(payloadSize).data + payloadData + padding
            
            // Buffer should only contain unsent data
            self.sendBuffer = Data()
            
            // Keep calling network.send if the leftover data is at least chunk size
            guard network.write(data: dataChunk)
            else
            {
                self.log.error("Replicant Connection write failed.")
                self.bufferLock.leave()
                return
            }
            
            self.bufferLock.leave()
            return
        }
    }
    
}

enum ToneBurstError: Error
{
    case generateFailure
    case removeFailure
}

enum IntroductionsError: Error
{
    case nilStateHandler
}
