//
//  WispProtocol.swift
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

import Logging
import Foundation

import CryptoSwift
import Elligator
import HKDF
import Sodium
import Transmission
import Transport

#if os(Linux)
import NetworkLinux
#else
import Network
#endif

enum WispPacketType: UInt8
{
    case payload = 0
    case seed = 1
    
    var data: Data
    {
        get
        {
            return Data([self.rawValue])
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
    let log: Logger
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
            
            // P_C
            guard let padding = randomBytes(number: self.padLength)
                else
            {
                log.error("Unable to generate padding for client handshake")
                return nil
            }
            
            // Mark
            guard  let mark = try? self.mac.authenticate(self.keypair.representative.bytes)
                else
            {
                log.error("Unable to create hmac for mark.")
                return nil
            }
            
            // Write X, P_C, M_C.
            handshakeBuffer.append(publicKeyRepresentative)
            handshakeBuffer.append(padding)
            handshakeBuffer.append(contentsOf: mark[0 ..< markLength])
            
            // Calculate and write the MAC.
            
            guard let macOfBuffer: Bytes = try? self.mac.authenticate(handshakeBuffer.bytes + self.epochHour.utf8)
                else
            {
                log.error("Unable to create hmac for handshake buffer.")
                return nil
            }
            
            handshakeBuffer.append(contentsOf: macOfBuffer[0 ..< macLength])
            
            return handshakeBuffer
        }
    }
    
    init?(certString: String, sessionKey: Keypair, logger: Logger)
    {
        self.init(certString: certString, sessionKey: sessionKey, logger: logger, epochHourString: nil)
    }
    
    init?(certString: String, sessionKey: Keypair, logger: Logger, epochHourString: String?)
    {
        guard let (unpackedNodeID, unpackedPublicKey) = unpack(certString: certString)
            else
        {
            logger.error("Attempted to init ClientHandshake with invalid cert string.")
            return nil
        }
        
        self.log = logger
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
        
        logger.debug("\nGenerating mac object for client handshake.")
        logger.debug("unpacked public key: \(unpackedPublicKey.bytes)")
        
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
    let log: Logger
    let nodeID: Data
    let clientPublicKey: Data
    let sessionKey: Keypair
    let iatMode: Bool
    
    var network: Transmission.Connection
    var encoder: WispEncoder?
    var decoder: WispDecoder?
    var receivedBuffer = Data()
    var receivedDecodedBuffer = Data()
    
    init?(connection: Transmission.Connection, cert: String, iatMode enableIAT: Bool, logger: Logger)
    {
        log = logger
        network = connection
        iatMode = enableIAT
        
        guard let (certNodeID, certPublicKey) = unpack(certString: cert)
        else
        {
            return nil
        }
        
        (nodeID, clientPublicKey) = (certNodeID, certPublicKey)
        
        guard let keypair = newKeypair(logger: log)
        else
        {
            return nil
        }
        
        sessionKey = keypair
    }
    
    func connectWithHandshake(certString: String, sessionKey: Keypair, completion: @escaping (Error?) -> Void)
    {
        // Generate and send the client handshake.
        guard let newHandshake = ClientHandshake(certString: certString, sessionKey: sessionKey, logger: log)
        else
        {
            log.error("Unable to init client handshake.")
            completion(WispError.invalidCertString)
            return
        }
        
        guard let clientHandshakeBytes = newHandshake.data
        else
        {
            log.error("Unable to generate handshake.")
            completion(WispError.invalidClientHandshake)
            return
        }
        
        guard network.write(data: clientHandshakeBytes)
        else
        {
            self.log.error("Failed to send the client handshake.")
            completion(WispError.failedWrite)
            return
        }
        
        // Consume the server handshake.
        let maybeReadData = self.network.read(size: serverMinHandshakeLength)

        guard let readData = maybeReadData
            else
        {
            completion(WispError.invalidResponse)
            self.log.error("No data received when attempting to read server handshake 🤔")
            return
        }
        
        self.readServerHandshake(clientHandshake: newHandshake, buffer: readData, completion: completion)
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
            guard let readData = self.network.read(size: 1)
            else
            {
                completion(WispError.invalidResponse)
                return
            }
            
            let newBuffer = buffer + readData
            self.readServerHandshake(clientHandshake: clientHandshake, buffer: newBuffer, completion: completion)
            return

        case let .success(seed):
            /// TODO: Test, We are assuming that count refers to desired output size in bytes not bits. <------
            // HKDF
            let keyMaterial = deriveKey(algorithm: .sha256,
                                        seed: seed,
                                        info: mExpandString.data(using: .ascii),
                                        salt: tKeyString.data(using: .ascii),
                                        count: keyMaterialLength * 2)
            let encoderKey = Data(keyMaterial[0 ..< keyMaterialLength])
            let decoderKey = Data(keyMaterial[keyMaterialLength ..< keyMaterialLength * 2])
            let newEncoder = WispEncoder(withKey: encoderKey, logger: log)
            let newDecoder = WispDecoder(withKey: decoderKey, logger: log)
            
            self.encoder = newEncoder
            self.decoder = newDecoder
            
            completion(nil)
            return
        }
    }
    
    
    func parseServerHandshake(clientHandshake: ClientHandshake, response: Data) -> ParseServerHSResult
    {
        guard response.count > representativeLength * 2
        else
        {
            log.error("Server handshake length is too short. 🤭")
            return .failed
        }
        
        // Pull out the representative/AUTH.
        let serverRepresentative = Data(response[0 ..< representativeLength])
        let serverAuth = Data(response[representativeLength ..< representativeLength * 2])

        
        let serverRepresentativeBytes = serverRepresentative.withUnsafeBytes
        {
            (bufferPointer) -> [UInt8] in
            
            return [UInt8](bufferPointer)
        }
        
        // Derive the mark.
        guard let macOfRepresentativeBytes = try? clientHandshake.mac.authenticate(serverRepresentativeBytes)
            else
        {
            log.error("Unable to derive mark from sever handshake.")
            return .failed
        }
        
        log.debug("\nParsing Server handshake.")
        
        let serverMark = Data(macOfRepresentativeBytes[0 ..< markLength])
        let serverHandshake = ServerHandshake(serverAuth: serverAuth, serverRepresentative: serverRepresentative, serverMark: serverMark)
        
        // Attempt to find the mark + MAC.
        let startPosition = representativeLength + authLength + serverMinPadLength
        
        guard let serverMarkRange = response.range(of: serverMark)
        else
        {
            if response.count >= maxHandshakeLength
            {
                log.error("Parse server handshake error: Invalid Handshake")
                return .failed
            }
            else
            {
                log.info("Parse server handshake: Mark not found yet.")
                return .retry
            }
        }
        
        // Make sure that we found the mark within the correct range of data in the server response.
        guard !serverMarkRange.clamped(to: startPosition ..< maxHandshakeLength).isEmpty
        else
        {
            log.error("Mark was found but not where we expected it to be.")
            return .failed
        }
        
        log.debug("Found the mark in the correct range!")
        
        // Validate the MAC.
        let prefixIncludingMark = response[0 ..< serverMarkRange.upperBound]
        let epochHour = clientHandshake.epochHour
        
        guard let providedMac = self.network.read(size: macLength)
        else
        {
            print("Failed to read data after the server mark.")
            return .failed
        }
        
        let thingToMac = prefixIncludingMark.bytes + epochHour.utf8
        guard let calculatedMacBytes = try? clientHandshake.mac.authenticate(thingToMac)
        else
        {
            log.error("Error with calculating client mac")
            return .failed
        }
        
        let calculatedMac = Data(calculatedMacBytes[0 ..< macLength])
        
        guard providedMac == calculatedMac
        else
        {
            log.error("\nServer provided mac does not match what we believe the mac should be!")
            log.error("Calculated Mac:\(calculatedMac.bytes)")
            log.error("Server Provided Mac: \(providedMac.bytes)")
            
            log.error("\nThing to mac is \(thingToMac.count) long.")
            log.error("prefix length is \(prefixIncludingMark.count)")
            log.error("\nprefix including mark: \(prefixIncludingMark.bytes)")
            log.error("epoch hour: \(epochHour.utf8)")
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
        log.debug("\ngetSeedFromHandshake serverRepresentative: \(serverHandshake.serverRepresentative.bytes)")
        let serverPublicKey = publicKey(representative: serverHandshake.serverRepresentative)
        log.debug("Just used elligator to get serverPublicKey: \(serverPublicKey.bytes)")
        
        guard let (seed, auth) = ntorClientHandshake(clientKeypair: clientHandshake.keypair, serverPublicKey: serverPublicKey, idPublicKey: clientHandshake.serverIdentityPublicKey, nodeID: clientHandshake.nodeID)
            else
        {
            log.error("ntorClientHandshake failed")
            return nil
        }
        
        guard auth == serverHandshake.serverAuth
            else
        {
            log.error("Parse server handshake failed: invalid auth.")
            log.error("Server provided auth: \(serverHandshake.serverAuth.bytes)")
            log.error("Ntor client handshake auth: \(auth.bytes)")
            return nil
        }
        
        return seed
    }
    
    func readPackets(minRead: Int, maxRead: Int, completion: @escaping (Data?, NWError?) -> Void)
    {
        guard self.decoder != nil
            else
        {
            completion(nil, NWError.posix(POSIXErrorCode.EPROTO))
            return
        }
        
        let result = self.decoder!.decode(network: network)
        
        switch result
        {
        case .failed:
            completion(nil, NWError.posix(POSIXErrorCode.EPROTO))
            return
        case .retry:
            self.readPackets(minRead: minRead, maxRead: maxRead, completion: completion)
            return
        case let .success(decodedData, leftovers):
            if leftovers != nil
            {
                self.receivedBuffer = leftovers!
            }
            else
            {
                self.receivedBuffer = Data()
            }
            
            //Handle packet data writes to the decoded buffer
            self.handlePacketData(data: decodedData)
            if self.receivedDecodedBuffer.count >= minRead
            {
                if self.receivedDecodedBuffer.count > maxRead
                {
                    /// Slice
                    completion(self.receivedDecodedBuffer[0 ..< maxRead], nil)
                    return
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
    
    func handlePacketData(data: Data)
    {
        // Make a new packet
        guard let newPacket = WispPacket(data: data)
        else
        {
            log.error("Unable to create a new packet from data.")
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
                log.error("Received a seed packet. This is for iatMode which is not currently supported. 🤗")
            }
        }
    }
    
    /// ntorClientHandshake does the client side of a ntor handshake and returns status, KEY_SEED, and AUTH.
    func ntorClientHandshake(clientKeypair: Keypair, serverPublicKey: Data, idPublicKey: Data, nodeID: Data) -> (keySeed: Data, auth: Data)?
    {
//        log.debug("\n ☞ ☞ Client public key: \(clientKeypair.publicKey.bytes)")
//        log.debug(" ☞ ☞ Server public key: \(serverPublicKey.bytes)")
//        log.debug(" ☞ ☞ ID public key: \(idPublicKey.bytes)")
//        log.debug(" ☞ ☞ Node ID: \(nodeID.bytes)\n")
        
        var secretInput = Data()
        
        // Client side uses EXP(Y,x) | EXP(B,x)
        let sodium = Sodium()
        let zeroData = Data(repeating: 0x00, count: sharedSecretLength)
        
        let ephemeralSharedSecret = sodium.keyExchange.scalarMult(
            publicKey: serverPublicKey.bytes,
            secretKey: clientKeypair.privateKey.bytes)
        let staticSharedSecret = sodium.keyExchange.scalarMult(
            publicKey: idPublicKey.bytes,
            secretKey: clientKeypair.privateKey.bytes)

        guard !sodium.utils.equals(staticSharedSecret, zeroData.bytes)
        else
        {
            log.error("ntorClientHandshake: static shared secret is zero.")
            return nil
        }
        
        guard !sodium.utils.equals(ephemeralSharedSecret, zeroData.bytes)
        else
        {
            log.error("ntorClientHandshake: ephemeral shared secret is zero.")
            return nil
        }
        
        secretInput.append(Data(ephemeralSharedSecret))
        secretInput.append(Data(staticSharedSecret))
                
        guard let (keySeed, auth) = ntorCommon(secretInput: secretInput, nodeID: nodeID, bPublicKey: idPublicKey, xPublicKey: clientKeypair.publicKey, yPublicKey: serverPublicKey)
        else
        {
            return nil
        }
        
        return (keySeed: keySeed, auth: auth)
    }

    func ntorCommon(secretInput: Data, nodeID: Data, bPublicKey: Data, xPublicKey: Data, yPublicKey: Data) -> (keySeed: Data, auth: Data)?
    {
        //FIXME: Verify that we are returning the correct auth
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
        
        log.debug("\n 🤫 🤫 Secret input appending suffix: \(suffix.bytes)")
        
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
                    log.error("Unable to generate auth HMAC.")
                    return nil
                }
            }
            catch
            {
                log.error("Unable to generate tVerify HMAC.")
                return nil
            }
        }
        catch
        {
            log.error("Unable to generate tKey HMAC.")
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
    else { return nil }
    
    guard let (nodeID, publicKey) = unpack(certData: cert)
    else { return nil }
    
    return (nodeID, publicKey)
}

// Slice Data into 0..nodeIDLength (exclusive) and nodeIDLength...end
// Should be 20 bytes and 32 bytes
func unpack(certData cert: Data) -> (nodeID: Data, publicKey: Data)?
{
    guard cert.count == certLength
        else { return nil }

    // Get bytes from cert starting with 0 and ending with NodeIDLength
    let nodeIDArray = cert.prefix(upTo: nodeIDLength)
    let nodeID = Data(nodeIDArray)
    
    // Get bytes from cert starting with NodeIDLength and ending at the end of the string
    let pubKeyArray = cert.suffix(from: nodeIDLength)
    let pubKey = Data(pubKeyArray)
    
    guard nodeID.count == nodeIDLength, pubKey.count == publicKeyLength
    else { return nil }
    
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
func newKeypair(logger: Logger) -> Keypair?
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
        
        if let result = representative(privateKey: Data(sodiumKeypair.secretKey))
        {
            maybeKeypair = sodiumKeypair
            elligatorRepresentative = result.representative
        }
        
        count = count + 1
    }
    
    if elligatorRepresentative == nil
    {
        logger.debug("Failed to create elligator representative after \(count) attempts.")
        return nil
    }
    
    if let actualRepresentative = elligatorRepresentative?.bytes, let newKeypair = maybeKeypair
    {
        let wispKeypair = Keypair(publicKey: Data(newKeypair.publicKey) , privateKey: Data(newKeypair.secretKey), representative: Data(actualRepresentative))
        return wispKeypair
    }
    else
    {
        logger.debug("Failed to create elligator representative.")
        return nil
    }
}

func randomBytes(number: Int) -> Data?
{
    var data = Data(count: number)

    let result = data.withUnsafeMutableBytes
    {
        (mutableBytes) in

        SecRandomCopyBytes(kSecRandomDefault, number, mutableBytes)
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
