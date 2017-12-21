//
//  WispProtocol.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 10/30/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//
// The Wisp transport protocol is wire-compatible with the obfs4 transport and can use obfs4 servers as
// well as obfs4 configuration parameters.
//
// Wisp is a new implementaiton of the obfs4 protocol and is not guaranteed to be identical in
// implementation to other obfs4 implementations except when required for over-the-wire compatibility.

import Foundation
import NetworkExtension
import Sodium
import CryptoSwift
import Elligator
import HKDF

enum WispPacketType: UInt8
{
    case payload = 0
    case seed = 1
    
    var data: Data
    {
        get
        {
            return Data(bytes: [self.rawValue])
        }
    }
}

struct WispPacket
{
    var type: WispPacketType // will always be 0 for packets made by the client
    var length: UInt16 // Length of the payload (serialize as Big Endian).
    var payload: Data
    var padLength: Int
    
    var data: Data
    {
        get
        {
            var newData = Data()
            var bigEndianLength = length.bigEndian
            // Type
            newData.append(type.rawValue)
            // Length
            newData.append(Data(buffer:UnsafeBufferPointer(start: &bigEndianLength, count: 2)))
            newData.append(payload)
            newData.append(Data(capacity: padLength))
            
            return newData
        }
    }
    
    init?(data: Data)
    {
        guard let newType = WispPacketType(rawValue: data[0])
        else
        {
            return nil
        }
        
        type = newType
        let lengthBytes = data[1 ..< 3]
        length = lengthBytes.withUnsafeBytes{ $0.pointee }
        payload = data[3 ..< 3 + length]
        padLength = data.count - (3 + Int(length))
    }
}

struct Keypair
{
    let publicKey: Data
    let privateKey: Data
    /// The Elligator-compressed public key
    let representative: Data
}

struct ClientHandshake
{
    let keypair: Keypair
    let nodeID: Data
    let serverIdentityPublicKey: Data
    let padLength: Int
    let mac: HMAC
    
    var epochHour: String
    
    var data: Data?
    {
        get
        {
            var handshakeBuffer = Data()
            
            // X
            let publicKeyRepresentative = self.keypair.representative
            
            ///TODO: P_C
            guard let padding = randomBytes(number: self.padLength)
                else
            {
                print("Unable to generate padding for client handshake")
                return nil
            }
            
            //Mark
            guard  let mark = try? self.mac.authenticate(self.keypair.representative.bytes)
                else
            {
                print("Unable to create hmac for mark.")
                return nil
            }
            
            // Write X, P_C, M_C.
            handshakeBuffer.append(publicKeyRepresentative)
            handshakeBuffer.append(padding)
            handshakeBuffer.append(contentsOf: mark[0 ..< markLength])
            
            // Calculate and write the MAC.
            guard let macOfBuffer = try? self.mac.authenticate(handshakeBuffer.bytes + self.epochHour.bytes)
                else
            {
                print("Unable to create hmac for handshake buffer.")
                return nil
            }
            
            handshakeBuffer.append(contentsOf: macOfBuffer[0 ..< macLength])
            
            return handshakeBuffer
        }
    }
    
    init?(certString: String, sessionKey: Keypair)
    {
        self.init(certString: certString, sessionKey: sessionKey, epochHourString: nil)
    }
    
    init?(certString: String, sessionKey: Keypair, epochHourString: String?)
    {
        guard let (unpackedNodeID, unpackedPublicKey) = unpack(certString: certString)
            else
        {
            print("Attempted to init ClientHandshake with invalid cert string.")
            return nil
        }
        
        self.keypair = sessionKey
        self.nodeID = unpackedNodeID
        self.serverIdentityPublicKey = unpackedPublicKey
        
        // Pad Length
        let min = UInt32(clientMinPadLength)
        let max = UInt32(clientMaxPadLength)
        self.padLength = Int(arc4random_uniform(1 + max - min)) + clientMinPadLength
        
        // HMAC
        let hmac = HMAC(key: unpackedPublicKey.bytes + nodeID.bytes, variant: .sha256)
        self.mac = hmac
        
        // E
        if epochHourString == nil
        {
            let epochString = "\(ClientHandshake.getEpochHour())"
            self.epochHour = epochString
        }
        else
        {
            self.epochHour = epochHourString!
        }
    }
    
    /// Returns the number of hours since the UNIX epoch.
     static func getEpochHour() -> Int
    {
        let secondsSince1970 = Date().timeIntervalSince1970
        let hoursSince1970 = secondsSince1970/3600
        
        return Int(hoursSince1970)
    }
}

struct ServerHandshake
{
    var serverAuth: Data
    var serverRepresentative: Data
    var serverMark: Data
}

class WispProtocol
{
    let nodeID: Data
    let clientPublicKey: Data
    let sessionKey: Keypair
    let iatMode: Bool
    
    var network: NWTCPConnection
    var encoder: WispEncoder?
    var decoder: WispDecoder?
    var receivedBuffer = Data()
    var receivedDecodedBuffer = Data()
    
    init?(connection: NWTCPConnection, cert: String, iatMode enableIAT: Bool)
    {
        network = connection
        iatMode = enableIAT
        
        guard let (certNodeID, certPublicKey) = unpack(certString: cert)
        else
        {
            return nil
        }
        
        (nodeID, clientPublicKey) = (certNodeID, certPublicKey)
        
        guard let keypair = newKeypair()
        else
        {
            return nil
        }
        
        sessionKey = keypair
    }
    
    func connectWithHandshake(certString: String, sessionKey: Keypair, completion: @escaping (Error?) -> Void)
    {
        // Generate and send the client handshake.
        guard let newHandshake = ClientHandshake(certString: certString, sessionKey: sessionKey)
        else
        {
            print("Unable to init client handshake.")
            completion(WispError.invalidCertString)
            return
        }
        
        guard let clientHandshakeBytes = newHandshake.data
        else
        {
            print("Unable to generate handshake.")
            return
        }
        
        network.write(clientHandshakeBytes)
        { (maybeWriteError) in
            
            if let writeError = maybeWriteError
            {
                print("Received an error when writing client handshake to the network:")
                print(writeError.localizedDescription)
                return
            }
            
            // Consume the server handshake.
            self.network.readMinimumLength(serverMinHandshakeLength, maximumLength: maxHandshakeLength, completionHandler:
            {
                (maybeReadData, maybeReadError) in
                
                if let readError = maybeReadError
                {
                    print("Error reading from network:")
                    print(readError.localizedDescription)
                    
                    completion(readError)
                    return
                }
                
                guard let readData = maybeReadData
                else
                {
                    completion(WispError.invalidResponse)
                    return
                }
                
                self.readServerHandshake(clientHandshake: newHandshake, buffer: readData, completion: completion)
            })
        }
    }
    
    func readServerHandshake(clientHandshake: ClientHandshake, buffer: Data, completion:  @escaping (Error?) -> Void)
    {
        let result = self.parseServerHandshake(clientHandshake: clientHandshake, response: buffer)
        
        switch result
        {
        case .failed:
            completion(WispError.invalidServerHandshake)
            return
        case .retry:
            self.network.readMinimumLength(1, maximumLength: maxHandshakeLength - buffer.count)
            {
                (maybeReadData, maybeReadError) in
                
                if let readError = maybeReadError
                {
                    print("Error reading from network:")
                    print(readError.localizedDescription)
                    
                    completion(readError)
                    return
                }
                
                guard let readData = maybeReadData
                    else
                {
                    completion(WispError.invalidResponse)
                    return
                }
                
                let newBuffer = buffer + readData
                self.readServerHandshake(clientHandshake: clientHandshake, buffer: newBuffer, completion: completion)
                return
            }
        case let .success(seed):
            /// TODO: Test, We are assuming that count refers to desired output size in bytes not bits. <------
            // HKDF
            let keyMaterial = deriveKey(algorithm: .sha256,
                                        seed: seed,
                                        info: mExpandString.data(using: .ascii),
                                        salt: tKeyString.data(using: .ascii),
                                        count: keyLength * 2)
            let encoderKey = keyMaterial[0 ..< keyLength]
            let decoderKey = keyMaterial[keyLength ..< keyLength * 2]
            let newEncoder = WispEncoder(withKey: encoderKey)
            let newDecoder = WispDecoder(withKey: decoderKey)
            
            self.encoder = newEncoder
            self.decoder = newDecoder
            
            completion(nil)
            return
        }
    }
    
    func parseServerHandshake(clientHandshake: ClientHandshake, response: Data) -> ParseServerHSResult
    {
        // Pull out the representative/AUTH.
        let serverRepresentative = response[0 ..< representativeLength]
        let serverAuth = response[representativeLength ..< representativeLength * 2]
        
        // Derive the mark.
        guard let macOfRepresentativeBytes = try? clientHandshake.mac.authenticate(serverRepresentative.bytes)
            else
        {
            print("Unable to derive mark from sever handshake.")
            return .failed
        }
        
        let serverMark = Data(macOfRepresentativeBytes[0 ..< markLength])
        let serverHandshake = ServerHandshake(serverAuth: serverAuth, serverRepresentative: serverRepresentative, serverMark: serverMark)
        
        // Attempt to find the mark + MAC.
        let startPosition = representativeLength + authLength + serverMinPadLength
        
        guard let markStartPosition = findMarkMac(mark: serverMark, buf: response, startPos: startPosition, maxPos: maxHandshakeLength)
        else
        {
            if response.count >= maxHandshakeLength
            {
                print("Parse server handshake error: Invalid Handshake")
                return .failed
            }
            else
            {
                print("Parse server handshake error: Mark not found yet.")
                return .retry
            }
        }
        
        // Validate the MAC.
        let prefixIncludingMark = response[0 ..< markStartPosition + markLength]
        let epochHour = clientHandshake.epochHour
        let providedMac = response[markStartPosition + markLength ..< markStartPosition + markLength + macLength]
        
        guard let calculatedMacBytes = try? clientHandshake.mac.authenticate(prefixIncludingMark + epochHour.bytes)
        else
        {
            print("Error with calculating client mac")
            return .failed
        }
        
        let calculatedMac = Data(calculatedMacBytes[0 ..< macLength])
        
        guard providedMac == calculatedMac
        else
        {
            print("Server provided mac does not match what we believe the mac should be!")
            return .failed
        }

        guard let seed = getSeedFromHandshake(clientHandshake: clientHandshake, serverHandshake: serverHandshake)
        else
        {
            return .failed
        }

        return .success(seed: seed)
    }
    
    func getSeedFromHandshake(clientHandshake: ClientHandshake, serverHandshake: ServerHandshake) -> Data?
    {
        let serverPublicKey = publicKey(representative: serverHandshake.serverRepresentative)
        
        guard let (seed, auth) = ntorClientHandshake(clientKeypair: clientHandshake.keypair, serverPublicKey: serverPublicKey, idPublicKey: clientHandshake.serverIdentityPublicKey, nodeID: clientHandshake.nodeID)
            else
        {
            print("ntorClientHandshake failed")
            return nil
        }
        
        guard auth == serverHandshake.serverAuth
            else
        {
            print("Parse server handshake failed: invalid auth.")
            return nil
        }
        
        return seed
    }
    
    func readPackets(minRead: Int, maxRead: Int, completion: @escaping (Data?, Error?) -> Void)
    {
        // Attempt to read off the network.
        network.readMinimumLength(1, maximumLength: maxFrameLength)
        {
            (maybeData, maybeError) in
            
            if let error = maybeError
            {
                completion(nil, error)
                return
            }
            
            guard let receivedData = maybeData
            else
            {
                completion(nil, WispError.connectionClosed)
                return
            }
            
            self.receivedBuffer.append(receivedData)
            
            guard self.decoder != nil
            else
            {
                completion(nil, WispError.decoderNotFound)
                return
            }
            
            let result = self.decoder!.decode(framesBuffer: self.receivedBuffer)
            
            switch result
            {
            case .failed:
                completion(nil, WispError.decoderFailure)
                return
            case .retry:
                self.readPackets(minRead: minRead, maxRead: maxRead, completion: completion)
                return
            case let .success(decodedData, leftovers):
                self.receivedBuffer = leftovers
                
                //Handle packet data writes to the decoded buffer
                self.handlePacketData(data: decodedData)
                if self.receivedDecodedBuffer.count >= minRead
                {
                    if self.receivedDecodedBuffer.count > maxRead
                    {
                        /// Slice
                        completion(self.receivedDecodedBuffer[0 ..< maxRead], nil)
                    }
                    else
                    {
                        /// No Slice
                        completion(self.receivedDecodedBuffer, nil)
                    }
                }
                else
                {
                    self.readPackets(minRead: minRead, maxRead: maxRead, completion: completion)
                }
                return
            }
        }
    }
    
    func handlePacketData(data: Data)
    {
        // Make a new packet
        guard let newPacket = WispPacket(data: data)
        else
        {
            print("Unable to create a new packet from data.")
            return
        }
        
        switch newPacket.type
        {
        // Write the payload to the decoded buffer
        case .payload:
            self.receivedDecodedBuffer.append(newPacket.data)
        case .seed:
            if newPacket.payload.count == seedPacketPayloadLength
            {
                print("Received a seed packet. This is for iatMode which is not currently supported. 🤗")
            }
        }
    }
    
    /// ntorClientHandshake does the client side of a ntor handshake and returns status, KEY_SEED, and AUTH.
    func ntorClientHandshake(clientKeypair: Keypair, serverPublicKey: Data, idPublicKey: Data, nodeID: Data) -> (keySeed: Data, auth: Data)?
    {
        var secretInput = Data()
        
        // Client side uses EXP(Y,x) | EXP(B,x)
        let sodium = Sodium()
        let zeroData = Data(repeating: 0x00, count: sharedSecretLength)
        
        guard let ephemeralSharedSecret = sodium.keyExchange.sessionKeyPair(publicKey: clientKeypair.publicKey, secretKey: clientKeypair.privateKey, otherPublicKey: serverPublicKey, side: .CLIENT)
            else
        {
            print("ntorClientHandshake: Unable to derive ephermeral shared secret.")
            return nil
        }
        
        guard let staticSharedSecret = sodium.keyExchange.sessionKeyPair(publicKey: clientKeypair.publicKey, secretKey: clientKeypair.privateKey, otherPublicKey: idPublicKey, side: .CLIENT)
        else
        {
            print("ntorClientHandshake: Unable to derive static shared secret.")
            return nil
        }

        guard !sodium.utils.equals(staticSharedSecret.tx, zeroData)
        else
        {
            print("ntorClientHandshake: static shared secret is zero.")
            return nil
        }
        
        guard !sodium.utils.equals(ephemeralSharedSecret.tx, zeroData)
        else
        {
            print("ntorClientHandshake: ephemeral shared secret is zero.")
            return nil
        }
        
        secretInput.append(ephemeralSharedSecret.tx)
        secretInput.append(staticSharedSecret.tx)
        
        guard let (keySeed, auth) = ntorCommon(secretInput: secretInput, nodeID: nodeID, bPublicKey: idPublicKey, xPublicKey: clientKeypair.publicKey, yPublicKey: serverPublicKey)
        else
        {
            return nil
        }
        
        return (keySeed: keySeed, auth: auth)
    }

    func ntorCommon(secretInput: Data, nodeID: Data, bPublicKey: Data, xPublicKey: Data, yPublicKey: Data) -> (keySeed: Data, auth: Data)?
    {
        let protoID = protoIDString.data(using: .ascii)!
        let tMac = tMacString.data(using: .ascii)!
        let tKey = tKeyString.data(using: .ascii)!
        let tVerify = tVerifyString.data(using: .ascii)!
        let serverStringAsData = "Server".data(using: .ascii)!
        
        // secret_input/auth_input use this common bit, build it once.
        var suffix = bPublicKey
        suffix.append(bPublicKey)
        suffix.append(xPublicKey)
        suffix.append(yPublicKey)
        suffix.append(protoID)
        suffix.append(nodeID)
        
        // At this point secret_input has the 2 exponents, concatenated, append the
        // client/server common suffix.
        var sInput = secretInput
        sInput.append(suffix)
        
        // KEY_SEED = H(secret_input, t_key)
        do
        {
            let keySeedHmac = HMAC(key: tKey.bytes, variant: .sha256)
            let keySeed = try keySeedHmac.authenticate(sInput.bytes)
            // verify = H(secret_input, t_verify)
            do
            {
                let tVerifyHmac = try HMAC(key: tVerify.bytes, variant: .sha256).authenticate(sInput.bytes)
                
                // auth_input = verify | ID | B | Y | X | PROTOID | "Server"
                var authInput = Data(tVerifyHmac)
                authInput.append(suffix)
                authInput.append(serverStringAsData)
                
                do
                {
                    let authHmac = HMAC(key: tMac.bytes, variant: .sha256)
                    let auth = try authHmac.authenticate(authInput.bytes)
                    
                    return (Data(keySeed), Data(auth))
                }
                catch
                {
                    print("Unable to generate auth HMAC.")
                    return nil
                }
            }
            catch
            {
                print("Unable to generate tVerify HMAC.")
                return nil
            }
        }
        catch
        {
            print("Unable to generate tKey HMAC.")
            return nil
        }
    }
}

/// Takes an encoded cert string and returns a node id and public key.
func unpack(certString: String) -> (nodeID: Data, publicKey: Data)?
{
    // Base64 decode the cert string
    let maybeCert = serverCert(fromString: certString)
    
    guard let cert = maybeCert
    else
    {
        return nil
    }
    
    guard let (nodeID, publicKey) = unpack(certData: cert)
    else
    {
        print("Unable to unpack cert.")
        return nil
    }
    
    return (nodeID, publicKey)
}

// Slice Data into 0..nodeIDLength (exclusive) and nodeIDLength...end
// Should be 20 bytes and 32 bytes
func unpack(certData cert: Data) -> (nodeID: Data, publicKey: Data)?
{
    guard cert.count == certLength else
    {
        print("Cert length \(cert.count) is invalid.")
        return nil
    }

    // Get bytes from cert starting with 0 and ending with NodeIDLength
    let nodeIDArray = cert.prefix(upTo: nodeIDLength)
    let nodeID = Data(nodeIDArray)
    
    // Get bytes from cert starting with NodeIDLength and ending at the end of the string
    let pubKeyArray = cert.suffix(from: nodeIDLength)
    let pubKey = Data(pubKeyArray)
    
    guard nodeID.count == nodeIDLength, pubKey.count == publicKeyLength
    else
    {
        return nil
    }
    
    return (nodeID, pubKey)
}

// Base64 decode the cert string into a Data
func serverCert(fromString encodedString: String) -> Data?
{
    guard let plainData = Data(base64Encoded: encodedString + certSuffix, options: [])
    else
    {
        print("WispProtocol - serverCert: unable to decode string.")
        return nil
    }
    
    if plainData.count != certLength
    {
        print("WispProtocol - serverCert: incorrect cert length: \(plainData.count)")
        return nil
    }
    
    return plainData
}

// NewKeypair generates a new Curve25519 keypair, and optionally also generates
// an Elligator representative of the public key.
func newKeypair() -> Keypair?
{
    let sodium = Sodium()

    // Elligator compression of public key to get representative
    var elligatorRepresentative: Data?
    var maybeKeypair: Box.KeyPair?
    
    // Apply the Elligator transform.  This fails ~50% of the time.
    var count = 0
    while elligatorRepresentative == nil, count < 50
    {
        guard let sodiumKeypair = sodium.box.keyPair()
            else
        {
            return nil
        }
        
        if let result = representative(privateKey: sodiumKeypair.secretKey)
        {
            maybeKeypair = sodiumKeypair
            elligatorRepresentative = result.representative
        }
        
        count = count + 1
    }
    
    if elligatorRepresentative == nil
    {
        print("Failed to create elligator representative after \(count) attempts.")
        return nil
    }
    
    if let actualRepresentative = elligatorRepresentative?.bytes, let newKeypair = maybeKeypair
    {
        let wispKeypair = Keypair(publicKey: newKeypair.publicKey, privateKey: newKeypair.secretKey, representative: Data(actualRepresentative))
        return wispKeypair
    }
    else
    {
        return nil
    }
}

func randomBytes(number: Int) -> Data?
{
    var data = Data(count: number)

    let result = data.withUnsafeMutableBytes
    {
        (mutableBytes) in

        SecRandomCopyBytes(kSecRandomDefault, data.count, mutableBytes)
    }

    if result == errSecSuccess
    {
        return data
    }
    else
    {
        return nil
    }
}

func findMarkMac(mark: Data, buf: Data, startPos: Int, maxPos: Int) -> Int?
{
    if mark.count != markLength
    {
        print("BUG: Invalid mark length (findMarkMac:): \(mark.count)")
        return nil
    }
    
    var endPos = buf.count
    
    if startPos > endPos
    {
        return nil
    }
    
    if endPos > maxPos
    {
        endPos = maxPos
    }
    
    if endPos - startPos < markLength + macLength
    {
        return nil
    }
    
    // The client has to actually do a substring search since the server can and will send payload trailing the response.
    let subBuf = buf[startPos...endPos]
    guard let posRange = subBuf.range(of: mark)
    else
    {
        return nil
    }
    
    // Ensure that there is enough trailing data for the MAC.
    var pos = posRange.lowerBound
    if startPos + pos + markLength + macLength > endPos
    {
        return nil
    }
    
    // Return the index relative to the start of the slice.
    pos += startPos
    return pos
}
