//
//  MeekTCPConnection.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/24/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation
import NetworkExtension

func createMeekTCPConnection(provider: NEPacketTunnelProvider, to: URL, serverURL: URL) -> MeekTCPConnection
{
    return MeekTCPConnection(provider: provider, to: to, url: serverURL)
}

//func createMeekTCPConnection(connection: NWTCPConnection) -> MeekTCPConnection
//{
//    return MeekTCPConnection(connection: connection)
//}

class MeekTCPConnection: NWTCPConnection
{
    var serverURL: URL
    var frontURL: URL
    var network: NWTCPConnection
    var writeClosed = false
    
    let minLength = 1
    let maxLength = MemoryLayout<UInt32>.size
    
    init(provider: NEPacketTunnelProvider, to front: URL, url: URL)
    {
        serverURL = url
        frontURL = front
        
        let frontHostname = frontURL.host!
        
        let endpoint: NWEndpoint = NWHostEndpoint(hostname: frontHostname, port: "80")
        network = provider.createTCPConnectionThroughTunnel(to: endpoint, enableTLS: true, tlsParameters: nil, delegate: nil)
        
        super.init()
    }
    
//    init(connection: NWTCPConnection)
//    {
//        network = connection
//
//        super.init()
//    }
    
    override func readMinimumLength(_ minimum: Int, maximumLength maximum: Int, completionHandler completion: @escaping (Data?, Error?) -> Void)
    {
        
        network.readMinimumLength(minimum, maximumLength: maximum)
        {
            (data, error) in
            
            guard error == nil else
            {
                completion(nil, error)
                return
            }
            
            guard data != nil else
            {
                completion(nil, nil)
                return
            }
            
            let decoded = self.decodeResponse(data!)
            
            completion(decoded, nil)
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
        let encoded = encodePOST(data)!
        network.write(encoded)
        {
            (error) in

            completion(error)
        }
    }
    
    override func writeClose()
    {
        network.writeClose()
    }
    
    override func cancel()
    {
        network.cancel()
    }
    
    func encodePOST(_ data: Data) -> Data?
    {
        guard let host = serverURL.host
        else
        {
            print("Unable to resolver server host.")
            return nil
        }
        
        let sessionID = ""
        let header1 = "Host: \(host)"
        let header2 = "X-Session-Id: \(sessionID)"
        let header3 = "User-Agent: "
        let header4 = "Content-Type: application/x-www-form-urlencoded"
        let httpRequestString = "POST \(frontURL.path) HTTP/1.1 \r\n\(header1)\r\n\(header2)\r\n\(header3)\r\n\(header4)\r\n\r\n"
        
        var postData = httpRequestString.data(using: .utf8)
        if postData != nil
        {
            postData!.append(data)
        }

        return postData
    }
    
    func decodeResponse(_ data: Data) -> Data?
    {
        guard let emptyLineIndex = findEmptyLineIndex(data: data)
        else
        {
            print("Unable to find empty line.")
            return nil
        }
        
        let headerData = data.prefix(through: emptyLineIndex - 1)
        if let headerString = String(data: headerData, encoding: .ascii)
        {
            let lines = headerString.components(separatedBy: "\r\n")
            if let statusLine = lines.first
            {
                let statusComponents = statusLine.components(separatedBy: " ")
                print(statusComponents)
            }
        }
        
        let bodyData = data.suffix(from: emptyLineIndex)
        return bodyData
    }
    
    func findEmptyLineIndex(data: Data) -> Int?
    {
        var dataToCheck = data
        
        if let newlineIndex = dataToCheck.index(of: 10)
        {
            let next = dataToCheck[newlineIndex + 1]
            if next == 13
            {
                return newlineIndex + 1
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
    
}
