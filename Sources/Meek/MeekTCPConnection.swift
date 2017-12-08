//
//  MeekTCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/24/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension
import SecurityFoundation
import CryptoSwift
import ShapeshifterTesting

func createMeekTCPConnection(provider: PacketTunnelProvider, to: URL, serverURL: URL) -> MeekTCPConnection
{

    return MeekTCPConnection(provider: provider /* as! NEPacketTunnelProvider */, to: to, url: serverURL)
}

class MeekTCPConnection: NWTCPConnection
{
    var serverURL: URL
    var frontURL: URL
    var network: NWTCPConnection
    var privIsViable: Bool
    var privState: NWTCPConnectionState
    var bodyBuffer = Data()
    var sessionID = ""
    
    ///Meek server is no longer accepting POST
    var meekIsClosed = false
    
    let minLength = 1
    let maxLength = MemoryLayout<UInt32>.size
    
    enum MeekError: Error {
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
    
    ///Whether or not data can be transferred over a tcp connection.
    override var isViable: Bool
    {
        get
        {
            return privIsViable
        }
    }
    
    override var state: NWTCPConnectionState
    {
        get
        {
            return privState
        }
    }
    
    init(provider: PacketTunnelProvider, to front: URL, url: URL)
    {
        serverURL = url
        frontURL = front
        privIsViable = true
        privState = .connected
        
        
        let frontHostname = frontURL.host!
        
        let endpoint: NWEndpoint = NWHostEndpoint(hostname: frontHostname, port: "80")
        network = provider.createTCPConnectionThroughTunnel(to: endpoint, enableTLS: true, tlsParameters: nil, delegate: nil)
        
        super.init()
        
        sessionID = generateSessionID() ?? ""
    }
    
    ///Testing Only
    convenience init(testDate: Date)
    {
        let provider = FakePacketTunnelProvider()
        let sURL = URL(string: "http://TestServer.com")!
        let fURL = URL(string: "http://TestFront.com")!
        self.init(provider: provider, to: fURL, url: sURL)
    }
    
    ///Currrently this function ignores the minimum and maximum lengths provided.
    override func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
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
    
    override func readLength(_ length: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        readMinimumLength(length, maximumLength: length, completionHandler: completion)
    }

/*
     func (c *meekConn) roundTrip(sndBuf []byte) (recvBuf []byte, err error) {
     var req *http.Request
     var resp *http.Response
     
     for retries := 0; retries < maxRetries; retries++ {
     url := *c.args.url
     host := url.Host
     if c.args.front != "" {
     url.Host = c.args.front
     }
     
     req, err = http.NewRequest("POST", url.String(), bytes.NewReader(sndBuf))
     if err != nil {
     return nil, err
     }
     
     if c.args.front != "" {
     req.Host = host
     }
     
     req.Header.Set("X-Session-Id", c.sessionID)
     req.Header.Set("User-Agent", "")
     
     resp, err = c.transport.RoundTrip(req)
     if err != nil {
     return nil, err
     }
     
     if resp.StatusCode != http.StatusOK {
     err = fmt.Errorf("status code was %d, not %d", resp.StatusCode, http.StatusOK)
     if resp.StatusCode == http.StatusInternalServerError {
     return
     } else {
     time.Sleep(retryDelay)
     }
     } else {
     defer resp.Body.Close()
     recvBuf, err = ioutil.ReadAll(io.LimitReader(resp.Body, maxPayloadLength))
     return
     }
     }
     
     return
     }
*/
    override func write(_ data: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
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
    
    override func writeClose()
    {
        network.writeClose()
    }
    
    override func cancel()
    {
        privIsViable = false
        privState = .cancelled
        network.cancel()
    }
    
    func checkForData(responseBuffer: Data, completionHandler completion: @escaping (Error?) -> Void)
    {
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
        privState = .disconnected
        privIsViable = false
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
//            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
//            randomBytes.withUnsafeBytes {
//                _ = CC_SHA256($0, CC_LONG(randomBytes.count), &hash)
//            }
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
    
//    func sha256(data: Data) -> Data
//    {
//        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
//        data.withUnsafeBytes {
//            _ = CC_SHA256($0, CC_LONG(data.count), &hash)
//        }
//
//        return Data(bytes: hash)
//    }
}
