//
//  MeekTCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/24/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
//import NetworkExtension

import Crypto

import Transport
import SwiftQueue

public func createMeekTCPConnection(provider: PacketTunnelProvider, to: URL, serverURL: URL, logQueue: Queue<String>) -> MeekTCPConnection?
{
    let conn = MeekTCPConnection(provider: provider, to: to, url: serverURL, logQueue: logQueue)
    guard let c = conn
    else
    {
        return nil
    }

    return c
}

public class MeekTCPConnection: TCPConnection
{
    public var hasBetterPath: Bool
    {
        get
        {
            return network.hasBetterPath
        }
    }
    
    public var endpoint: NWEndpoint
    {
        get
        {
            return network.endpoint
        }
    }
    
    public var connectedPath: NWPath?
    public var localAddress: NWEndpoint?
    public var remoteAddress: NWEndpoint?
    public var txtRecord: Data?
    public var error: Error?
    
    public var serverURL: URL
    public var frontURL: URL
    public var network: TCPConnection
    public var bodyBuffer = Data()
    public var sessionID = ""
    
    ///Meek server is no longer accepting POST
    public var meekIsClosed = false
    
    private var logQueue: Queue<String>
    
    let minLength = 1
    let maxLength = MemoryLayout<UInt32>.size
    
    public enum MeekError: Error
    {
        case unknownError
        case connectionError
        case meekIsClosed
        case invalidRequest
        case notFound
        case invalidResponse
        case serverError
        case serverUnavailable
        case timeOut
        case unsuppotedURL
    }
    
    public var isViable: Bool
    {
        get
        {
            return _isViable
        }
    }
    
    public var state: NWTCPConnectionState
    {
        get
        {
            return _state
        }
    }

    public var stateCallback: ((NWTCPConnectionState, Error?) -> Void)?
    
    private var _isViable: Bool
    private var _error: Error?
    private var _state: NWTCPConnectionState
    {
        didSet
        {
            logQueue.enqueue("Meek Connection State has changed: \(_state.description)")
            NotificationCenter.default.post(name: .meekConnectionState, object: _state.description)
            guard let callback = stateCallback
            else { return }
            
            callback(_state, nil)
        }
    }
    
    public init?(provider: PacketTunnelProvider, to front: URL, url: URL, logQueue: Queue<String>)
    {
        self.logQueue = logQueue
        
        serverURL = url
        frontURL = front

        let frontHostname = frontURL.host!
        let endpoint: NWEndpoint = NWHostEndpoint(hostname: frontHostname, port: "80")
        
        guard let tcpConnection = provider.createTCPConnectionThroughTunnel(to: endpoint, enableTLS: true, tlsParameters: nil, delegate: nil)
        else
        {
            return nil
        }

        network = tcpConnection
        _state = .connected
        _isViable = true
        sessionID = generateSessionID() ?? ""
    }
    
    public func observeState(_ callback: @escaping (NWTCPConnectionState, Error?) -> Void) {
        self.stateCallback=callback
    }
    
    // Currrently this function ignores the minimum and maximum lengths provided.
    public func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        guard isViable
        else
        {
            let error = MeekError.connectionError
            completion(nil, error)
            return
        }
        
        guard !meekIsClosed
        else
        {
            let data = self.bodyBuffer
            self.bodyBuffer = Data()
            self.cleanup()
            completion(data, nil)
            return
        }
        
        write(Data())
        {
            (maybeError) in
            
            if let writeError = maybeError
            {
                if self.bodyBuffer.isEmpty
                {
                    completion(nil, writeError)
                }
                else
                {
                    let data = self.bodyBuffer
                    self.bodyBuffer = Data()
                    completion(data, nil)
                }
            }
            else
            {
                let data = self.bodyBuffer
                self.bodyBuffer = Data()
                completion(data, nil)
            }
        }
    }
    
    public func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        logQueue.enqueue("Meek readLength Called")
        readMinimumLength(length, maximumLength: length, completionHandler: completion)
    }

    public func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
        logQueue.enqueue("Meek Write Called")
        guard isViable
        else
        {
            let error = MeekError.connectionError
            completion(error)
            return
        }
        
        guard !meekIsClosed
        else
        {
            let error = MeekError.meekIsClosed
            completion(error)
            return
        }
        
        let encoded = encodePOST(data)!
        network.write(encoded)
        {
            (error) in

            self.checkForData(responseBuffer: Data(), completionHandler: completion)
        }
    }
    
    public func writeClose()
    {
        network.writeClose()
    }
    
    public func cancel()
    {
        _isViable = false
        _state = .cancelled
        network.cancel()
    }
    
    func checkForData(responseBuffer: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
        logQueue.enqueue("Meek checkForData Called")
        self.network.readMinimumLength(60, maximumLength: 60 + 65536, completionHandler:
        {
            (maybeData, maybeError) in
            
            var dataBuffer = responseBuffer
            
            guard maybeError == nil
            else
            {
                print("Received an error when attempting to read from the network:")
                print(maybeError!)
                completion(nil)
                return
            }
            
            guard let someData = maybeData
            else
            {
                completion(nil)
                return
            }
            
            dataBuffer.append(someData)
            
            let (maybeStatusCode, maybeBody) = self.decodeResponse(dataBuffer)
            
            guard let statusCode = maybeStatusCode
            else
            {
                self.checkForData(responseBuffer: dataBuffer, completionHandler: completion)
                return
            }
            
            guard statusCode == "200"
            else
            {
                self.logQueue.enqueue("Meek status code is not 200")
                if self.bodyBuffer.isEmpty
                {
                    self.cleanup()
                }
                else
                {
                    self.meekIsClosed = true
                    self.network.cancel()
                }
                
                return
            }
            
            self.logQueue.enqueue("Meek Server response status code is 200.")
            
            guard let bodyData = maybeBody
            else
            {
                self.checkForBody(responseBuffer: Data(), completionHandler: completion)
                return
            }
            
            self.checkForBody(responseBuffer: bodyData, completionHandler: completion)
        })
    }
    
    func checkForBody(responseBuffer: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
        self.network.readMinimumLength(1, maximumLength: 65536, completionHandler:
        {
            (maybeData, maybeError) in
            
            var dataBuffer = responseBuffer
            
            guard maybeError == nil
                else
            {
                self.bodyBuffer.append(dataBuffer)
                completion(nil)
                return
            }
            
            guard let someData = maybeData
                else
            {
                self.bodyBuffer.append(dataBuffer)
                completion(nil)
                return
            }
            
            dataBuffer.append(someData)
            self.checkForBody(responseBuffer: dataBuffer, completionHandler: completion)
        })
    }
    
    func encodePOST(_ data: Data) -> Data?
    {
        guard let host = serverURL.host
        else
        {
            print("Unable to resolver server host.")
            return nil
        }
        
        let header1 = "Host: \(host)"
        let header2 = "X-Session-Id: \(sessionID)"
        let httpRequestString = "POST \(frontURL.path) HTTP/1.1 \r\n\(header1)\r\n\(header2)\r\n\r\n"
        
        var postData = httpRequestString.data(using: .utf8)
        if postData != nil
        {
            postData!.append(data)
        }

        return postData
    }
    
    func decodeResponse(_ data: Data) -> (statusCode: String?, body: Data?)
    {
        logQueue.enqueue("Meek: Decoding Server Response")
        guard let (headerString, bodyData) = splitOnBlankLine(data: data)
        else
        {
            return (nil, nil)
        }
        
        let statusCode = getStatusCode(fromHeader: headerString)
        
        return (statusCode, bodyData)
    }
    
    func cleanup()
    {
        network.cancel()
        _state = .disconnected
        _isViable = false
    }
    
    func getStatusCode(fromHeader headerString: String) -> String?
    {
        let lines = headerString.components(separatedBy: "\r\n")
        
        guard let statusLine = lines.first
        else
        {
            return nil
        }
        
        let statusComponents = statusLine.components(separatedBy: " ")
        let statusCodeString = statusComponents[1]
        
        return statusCodeString
    }
    
    func splitOnBlankLine(data: Data) -> (header: String, body: Data)?
    {
        guard let emptyLineIndex = findEmptyLineIndex(data: data)
            else
        {
            print("Unable to find empty line.")
            return nil
        }
        
        let headerData = data.prefix(through: emptyLineIndex - 2)
        if let headerString = String(data: headerData, encoding: .ascii)
        {
            let bodyData = data.suffix(from: emptyLineIndex + 3)
            return (headerString, bodyData)
        }
        else
        {
            return nil
        }
    }
    
    func findEmptyLineIndex(data: Data) -> Int?
    {
        var dataToCheck = data
        
        if let newlineIndex = dataToCheck.index(of: 10)
        {
            let next = dataToCheck[newlineIndex + 1]
            if next == 13
            {
                return newlineIndex
            }
            else
            {
                if dataToCheck.count > 2
                {
                    dataToCheck = dataToCheck.suffix(from: newlineIndex + 1)
                    return findEmptyLineIndex(data: dataToCheck)
                }
                else
                {
                    return nil
                }
            }
        }
        else
        {
            return nil
        }
    }
    
    ///This generates a random hex string of random bytes using SHA256.
    func generateSessionID() -> String?
    {
        let byteCount = 64
        var randomHex = ""
        var randomBytesArray = [UInt8](repeating: 0, count: byteCount)
        
        //Create an array of random bytes.
        let result = SecRandomCopyBytes(kSecRandomDefault, byteCount, &randomBytesArray)
        if result == errSecSuccess
        {
            //Create data from bytes array.
            let randomBytes = Data(bytes: randomBytesArray)
            
            //SHA256 random bytes.
            let hash = randomBytes.sha256()

            //Create hex from the first 16 values of the hash array.
            let first16Hash = hash.prefix(16)
            let hexArray = first16Hash.map({String(format: "%02hhx", $0)})
            randomHex = hexArray.joined(separator: "")
            
            //🔮
            return randomHex
        }
        else
        {
            return nil
        }
    }
    
    //    ///Testing Only <-------------------
    //    convenience init?(testDate: Date)
    //    {
    //        let provider = FakePacketTunnelProvider()
    //        let sURL = URL(string: "http://TestServer.com")!
    //        let fURL = URL(string: "http://TestFront.com")!
    //        self.init(provider: provider, to: fURL, url: sURL)
    //    }
    
    //func createMeekTCPConnection(testDate: Date) -> MeekTCPConnection?
    //{
    //    let conn = MeekTCPConnection(testDate: testDate)
    //    guard let c = conn
    //    else
    //    {
    //        return nil
    //    }
    //
    //    return c
    //}

}

public extension Notification.Name
{
    static let meekConnectionState = Notification.Name("MeekTCPConnectionState")
}

extension NWTCPConnectionState: CustomStringConvertible
{
    public var description: String
    {
        switch self
        {
        case .cancelled: return "Cancelled"
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected: return "Disconnected"
        case .invalid: return "Invalid"
        case .waiting: return "Waiting"
        }
    }
}
