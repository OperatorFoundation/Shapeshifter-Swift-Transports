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

// PublicKeyLength is the length of a Curve25519 public key.
let publicKeyLength = 32
let certLength = nodeIDLength + publicKeyLength
let markLength = sha256Size/2
let nodeIDLength = 20
let certSuffix = "=="
let sha256Size = 32

// Handshake Constants

// ----> TODO: Find what these should be from golang project
let frameOverhead = 5 // framing.FrameOverhead
let packetOverhead = 5
let seedPacketPayloadLength = 5
//...

let representativeLength = 32 // RepresentativeLength is the length of an Elligator representative.
let serverMinPadLength = 0
let maxHandshakeLength = 8192
let macLength  = sha256Size/2
let sharedSecretLength = 32 /// SharedSecretLength is the length of a Curve25519 shared secret.
let authLength = sha256Size // AuthLength is the length of the derived AUTH.
let keySeedLength = sha256Size // KeySeedLength is the length of the derived KEY_SEED.
let serverMaxPadLength = maxHandshakeLength - (serverMinHandshakeLength + inlineSeedFrameLength)
let clientMinHandshakeLength = representativeLength + markLength + macLength
let clientMinPadLength = (serverMinHandshakeLength + inlineSeedFrameLength) - clientMinHandshakeLength
let clientMaxPadLength = maxHandshakeLength - clientMinHandshakeLength
let serverMinHandshakeLength = representativeLength + authLength + markLength + macLength
let inlineSeedFrameLength = frameOverhead + packetOverhead + seedPacketPayloadLength

var protoIDString = "ntor-curve25519-sha256-1" // Data(base64Encoded: "ntor-curve25519-sha256-1")
var tMacString = protoIDString + ":mac" // append(protoID, []byte(":mac")...)
var tKeyString = protoIDString + ":key_extract" // append(protoID, []byte(":key_extract")...)
var tVerifyString = protoIDString + ":key_verify" // append(protoID, []byte(":key_verify")...)
var mExpandString = protoIDString + ":key_expand" // append(protoID, []byte(":key_expand")...)

enum WispPacketType: UInt8
{
    case payload = 0
    case seed = 1
}

struct WispPacket
{
    var type: WispPacketType // will always be 0 for packets made by the client
    var length: UInt16         // Length of the payload (serialize as Big Endian).
    var payload: Data
    var padding: Data
}

struct Keypair
{
    let publicKey: Data
    let privateKey: Data
    let representative: Data // The Elligator-compressed public key
}

struct ClientHandshake
{
    let keypair: Keypair
    let nodeID: Data
    let serverIdentityPublicKey: Data // *ntor.PublicKey
    let padLength: Int
    let mac: HMAC // hash.Hash
    
    var serverRepresentative: Data? //*ntor.Representative
    var serverAuth: Data? // *ntor.Auth
    var serverMark: Data? // []byte
    var epochHour: String? // []byte
    
    init(nodeID: Data, serverIdentity: Data, sessionKey: Keypair)
    {
        self.keypair = sessionKey
        self.nodeID = nodeID
        self.serverIdentityPublicKey = serverIdentity
        
        // Pad Length
        let min = UInt32(clientMinPadLength)
        let max = UInt32(clientMaxPadLength)
        self.padLength = Int(arc4random_uniform(1 + max - min)) + clientMinPadLength
        
        // HMAC
        let hmac = HMAC(key: serverIdentity.bytes + nodeID.bytes, variant: .sha256)
        self.mac = hmac
    }
}

struct ServerHandshake
{
    let keypair: Keypair
    let nodeID: Data
    let serverIdentityKeypair: Keypair
    let padLength: Int
    let mac: HMAC
    
    var epochHour: String?
    var serverAuth: Data?
    var clientRepresentative: Data?
    var clientMark: Data?
    
    init(nodeID: Data, serverIdentity: Keypair, sessionKey: Keypair)
    {
        self.keypair = sessionKey
        self.nodeID = nodeID
        self.serverIdentityKeypair = serverIdentity
        
        // Pad Length
        let min = UInt32(serverMinPadLength)
        let max = UInt32(serverMaxPadLength)
        self.padLength = Int(arc4random_uniform(1 + max - min)) + clientMinPadLength
        
        // HMAC
        let hmac = HMAC(key: serverIdentityKeypair.publicKey.bytes + nodeID.bytes, variant: .sha256)
        self.mac = hmac
    }
}

//struct MAC
//{
//    let secret: Data
//
//    init(serverIdentity: Data, nodeID: Data)
//    {
//        var newSecret = serverIdentity
//        newSecret.append(nodeID)
//
//        secret = newSecret
//    }
//
////    func computeMAC(someData: Data) -> Data
////    {
////
////        let key = Array<UInt8>(someData)
////        let mac = HMAC(key: key)
////    }
//}

struct WispProtocol
{
    let nodeID:     Data
    let publicKey:  Data
    let sessionKey: Keypair
    
    let iatMode: Bool
    var network: NWTCPConnection
    
    init?(connection: NWTCPConnection, cert: String, iatMode enableIAT: Bool)
    {
        network = connection
        iatMode = enableIAT
        
        guard let (certNodeID, certPublicKey) = unpack(certString: cert)
        else
        {
            return nil
        }
        
        (nodeID, publicKey) = (certNodeID, certPublicKey)
        
        guard let keypair = newKeypair()
        else
        {
            return nil
        }
        
        sessionKey = keypair
    }
    
    func connectWithHandshake(nodeID: Data, peerIdentityKey: Data, sessionKey: Keypair)
    {
        /*
         if conn.isServer
         {
         return fmt.Errorf("clientHandshake called on server connection")
         }
         */
        
        // Generate and send the client handshake.
        let newHandshake = ClientHandshake(nodeID: nodeID, serverIdentity: peerIdentityKey, sessionKey: sessionKey)
        
        guard let (clientHandshake, blob) = generateClientHandshake(handshake: newHandshake)
        else
        {
            print("Unable to generate handshake.")
            return
        }
        
        network.write(blob)
        { (maybeWriteError) in
            
            if let writeError = maybeWriteError
            {
                print("Received an error when writing client handshae to the network:")
                print(writeError.localizedDescription)
                return
            }
            
            // Consume the server handshake.
            
            ///TODO: Loop needed here <---
            self.network.readMinimumLength(serverMinHandshakeLength, maximumLength: maxHandshakeLength, completionHandler: 
            {
                (maybeReadData, maybeReadError) in
                
                if let readError = maybeReadError
                {
                    print("Error reading from network:")
                    print(readError.localizedDescription)
                }
                
                if let readData = maybeReadData
                {
                    guard let (index, seed) = self.parseServerHandshake(clientHandshake: clientHandshake, response: readData)
                    else
                    {
                        return
                    }
                    
                    
                    ///TODO
                    /*
                    _ = conn.receiveBuffer.Next(n)
                    
                    // Use the derived key material to intialize the link crypto.
                    okm := ntor.Kdf(seed, framing.KeyLength*2)
                    conn.encoder = framing.NewEncoder(okm[:framing.KeyLength])
                    conn.decoder = framing.NewDecoder(okm[framing.KeyLength:])
                     */
                }
            })
        }
    }
    
    /*
     func (conn *obfs4Conn) clientHandshake(nodeID *ntor.NodeID, peerIdentityKey *ntor.PublicKey, sessionKey *ntor.Keypair) error
     {
         if conn.isServer
         {
             return fmt.Errorf("clientHandshake called on server connection")
         }
     
         // Generate and send the client handshake.
         hs := newClientHandshake(nodeID, peerIdentityKey, sessionKey)
         blob, err := hs.generateHandshake()
     
         if err != nil
         {
             return err
         }
     
         if _, err = conn.Conn.Write(blob); err != nil
         {
             return err
         }
     
         // Consume the server handshake.
         var hsBuf [maxHandshakeLength]byte
     
         for
         {
             n, err := conn.Conn.Read(hsBuf[:])
             if err != nil
             {
                 // The Read() could have returned data and an error, but there is
                 // no point in continuing on an EOF or whatever.
                 return err
             }
             conn.receiveBuffer.Write(hsBuf[:n])
     
             n, seed, err := hs.parseServerHandshake(conn.receiveBuffer.Bytes())
     
             if err == ErrMarkNotFoundYet
             {
                 continue
             }
             else if err != nil
             {
                 return err
             }
     
             _ = conn.receiveBuffer.Next(n)
     
             // Use the derived key material to intialize the link crypto.
             okm := ntor.Kdf(seed, framing.KeyLength*2)
             conn.encoder = framing.NewEncoder(okm[:framing.KeyLength])
             conn.decoder = framing.NewDecoder(okm[framing.KeyLength:])
     
             return nil
         }
     }
     */
    
    func generateClientHandshake(handshake: ClientHandshake) -> (handshake: ClientHandshake, buffer: Data)?
    {
        var handshake = handshake
        var handshakeBuffer = Data()
        
        /// X
        let publicKeyRepresentative = handshake.keypair.representative
        handshakeBuffer.append(publicKeyRepresentative)
        
        ///TODO: P_C
        let padArray = Padding.pkcs7.add(to: [], blockSize: handshake.padLength) // <--- Incorrect use of this pad function.
        handshakeBuffer.append(contentsOf: padArray)
        
        ///Mark
        let mark = handshake.keypair.representative.suffix(markLength) // <--- Unsure about use of length here
        handshake.serverMark = mark
        
        do
        {
            let hmacOfMark = try handshake.mac.authenticate(mark.bytes)
            handshakeBuffer.append(contentsOf: hmacOfMark)
        }
        catch
        {
            print("Unable to create hmac for mark.")
            return nil
        }
        
        /// E
        let epochHour = "\(getEpochHour())"
        handshake.epochHour = epochHour
        
        // Calculate and write the MAC.
        do
        {
            let macOfBuffer = try handshake.mac.authenticate(handshakeBuffer.bytes + epochHour.bytes)
            // <--- Unsure about use of length here
            handshakeBuffer.append(contentsOf: macOfBuffer)
        }
        catch
        {
            print("Unable to create hmac for handshake buffer.")
            return nil
        }

        /*func (hs *clientHandshake) generateHandshake() ([]byte, error)
         {
         *var buf bytes.Buffer
         
         hs.mac.Reset()
         *hs.mac.Write(hs.keypair.Representative().Bytes()[:])
         *mark := hs.mac.Sum(nil)[:markLength]
         
         // The client handshake is X | P_C | M_C | MAC(X | P_C | M_C | E) where:
         //  * X is the client's ephemeral Curve25519 public key representative.
         //  * P_C is [clientMinPadLength,clientMaxPadLength] bytes of random padding.
         //  * M_C is HMAC-SHA256-128(serverIdentity | NodeID, X)
         //  * MAC is HMAC-SHA256-128(serverIdentity | NodeID, X .... E)
         //  * E is the string representation of the number of hours since the UNIX
         //    epoch.
         
         // Generate the padding
         /*
         pad, err := makePad(hs.padLen)
         if err != nil
         {
         return nil, err
         }
         */
         
         // Write X, P_C, M_C.
         *buf.Write(hs.keypair.Representative().Bytes()[:])
         *buf.Write(pad)
         *buf.Write(mark)
         
         // Calculate and write the MAC.
         hs.mac.Reset()
         *hs.mac.Write(buf.Bytes())
         *hs.epochHour = []byte(strconv.FormatInt(getEpochHour(), 10))
         
         *hs.mac.Write(hs.epochHour)
         *buf.Write(hs.mac.Sum(nil)[:macLength])
         
         return buf.Bytes(), nil
         }*/
        
        return (handshake, handshakeBuffer)
    }
    
    func parseServerHandshake(clientHandshake: ClientHandshake, response: Data) -> (index: Int, seed: Data)?
    {
        if serverMinHandshakeLength > response.count
        {
            print("parseServerHandshake Error: Mark not found yet.")
            return(nil)
        }
        
        if clientHandshake.serverRepresentative == nil || clientHandshake.serverAuth == nil
        {
            /// TODO: Representative, Auth, Mark
            /*
            // Pull out the representative/AUTH. (XXX: Add ctors to ntor)
            hs.serverRepresentative = new(ntor.Representative)
            copy(hs.serverRepresentative.Bytes()[:], resp[0:ntor.RepresentativeLength])
            hs.serverAuth = new(ntor.Auth)
            copy(hs.serverAuth.Bytes()[:], resp[ntor.RepresentativeLength:])
            
            // Derive the mark.
            hs.mac.Reset()
            hs.mac.Write(hs.serverRepresentative.Bytes()[:])
            hs.serverMark = hs.mac.Sum(nil)[:markLength]
             */
        }
        
        // Attempt to find the mark + MAC.
        guard let clientMark = clientHandshake.serverMark
        else
        {
            print("Unable to parse server handshake: client handshake mark not found.")
            return nil
        }
        
        let startPosition = representativeLength + authLength + serverMinPadLength
        
        guard let pos = findMarkMac(mark: clientMark, buf: response, startPos: startPosition, maxPos: maxHandshakeLength, fromTail: false)
        else
        {
            if response.count >= maxHandshakeLength
            {
                print("Parse server handshake error: Invalid Handshake")
            }
            else
            {
                print("Parse server handshake error: Mark not found yet.")
            }
            
            return nil
        }
        
        // Validate the MAC.
//        hs.mac.Reset()
//        hs.mac.Write(resp[:pos+markLength])
        let mark = response.prefix(upTo: pos + markLength)
//        hs.mac.Write(hs.epochHour)
        guard let epochHour = clientHandshake.epochHour
        else
        {
            print("Unable to get epoch hour from client handshake.")
            return nil
        }
//        macCmp := hs.mac.Sum(nil)[:macLength]
        
        let macCmp = mark + epochHour.bytes
//        macRx := resp[pos+markLength : pos+markLength+macLength]
        
        let macRx = response.subdata(in: pos + markLength..<pos + markLength + macLength)
        
        do
        {
            let serverMac = try clientHandshake.mac.authenticate(macRx.bytes)
            
            do
            {
                let clientMac = try clientHandshake.mac.authenticate(macCmp.bytes)
                
                if serverMac == clientMac
                {
                    // Complete the handshake.
                    guard let serverPublicKey = Elligator.publicKey(fromRepresentative: clientHandshake.serverRepresentative)
                    else
                    {
                        print("Unable to get public key from representative while parsing server handshake.")
                        return nil
                    }
                    
//                    serverPublic := hs.serverRepresentative.ToPublic()
//                    ok, seed, auth := ntor.ClientHandshake(hs.keypair, serverPublic, hs.serverIdentity, hs.nodeID)
//                    if !ok
//                    {
//                        return 0, nil, ErrNtorFailed
//                    }
//                    if !ntor.CompareAuth(auth, hs.serverAuth.Bytes()[:])
//                    {
//                        return 0, nil, &InvalidAuthError{auth, hs.serverAuth}
//                    }
//
//                    return pos + markLength + macLength, seed.Bytes()[:], nil
                    
                    guard let (seed, auth) = ntorClientHandshake(clientKeypair: clientHandshake.keypair, serverPublicKey: serverPublicKey, idPublicKey: clientHandshake.serverIdentityPublicKey, nodeID: clientHandshake.nodeID)
                    else
                    {
                        print("ntorClientHandshake failed")
                        return nil
                    }
                    
                    guard auth == clientHandshake.serverAuth
                    else
                    {
                        print("Parse server handshake failed: invalid auth.")
                        return nil
                    }

                    return (pos + markLength + macLength, seed)
                }
                else
                {
                    print("Server mac and client mac do not match.")
                    return nil
                }
            }
            catch
            {
                print("Error with calculating client mac:")
                print(error.localizedDescription)
                return nil
            }
        }
        catch
        {
            print("Error with calculating server mac:")
            print(error.localizedDescription)
            return nil
        }
    }
    
    /*
     func (hs *clientHandshake) parseServerHandshake(resp []byte) (int, []byte, error)
     {
         // No point in examining the data unless the miminum plausible response has
         // been received.
         if serverMinHandshakeLength > len(resp)
         {
             return 0, nil, ErrMarkNotFoundYet
         }
     
         if hs.serverRepresentative == nil || hs.serverAuth == nil
         {
             // Pull out the representative/AUTH. (XXX: Add ctors to ntor)
             hs.serverRepresentative = new(ntor.Representative)
             copy(hs.serverRepresentative.Bytes()[:], resp[0:ntor.RepresentativeLength])
             hs.serverAuth = new(ntor.Auth)
             copy(hs.serverAuth.Bytes()[:], resp[ntor.RepresentativeLength:])
     
             // Derive the mark.
             hs.mac.Reset()
             hs.mac.Write(hs.serverRepresentative.Bytes()[:])
             hs.serverMark = hs.mac.Sum(nil)[:markLength]
         }
     
         // Attempt to find the mark + MAC.
         pos := findMarkMac(hs.serverMark, resp, ntor.RepresentativeLength+ntor.AuthLength+serverMinPadLength,
         maxHandshakeLength, false)
         if pos == -1
         {
             if len(resp) >= maxHandshakeLength
             {
             return 0, nil, ErrInvalidHandshake
             }
             return 0, nil, ErrMarkNotFoundYet
         }
     
         // Validate the MAC.
         hs.mac.Reset()
         hs.mac.Write(resp[:pos+markLength])
         hs.mac.Write(hs.epochHour)
         macCmp := hs.mac.Sum(nil)[:macLength]
         macRx := resp[pos+markLength : pos+markLength+macLength]
         if !hmac.Equal(macCmp, macRx)
         {
             return 0, nil, &InvalidMacError{macCmp, macRx}
         }
     
         // Complete the handshake.
         serverPublic := hs.serverRepresentative.ToPublic()
         ok, seed, auth := ntor.ClientHandshake(hs.keypair, serverPublic,
         hs.serverIdentity, hs.nodeID)
         if !ok
         {
             return 0, nil, ErrNtorFailed
         }
         if !ntor.CompareAuth(auth, hs.serverAuth.Bytes()[:])
         {
             return 0, nil, &InvalidAuthError{auth, hs.serverAuth}
         }
     
         return pos + markLength + macLength, seed.Bytes()[:], nil
     }
     */
    
    /// ntorClientHandshake does the client side of a ntor handshake and returns status, KEY_SEED, and AUTH.
    func ntorClientHandshake(clientKeypair: Keypair, serverPublicKey: Data, idPublicKey: Data, nodeID: Data) -> (keySeed: Data, auth: Data)?
    {
        /// If status is not true or AUTH does not match the value recieved from the server, the handshake MUST be aborted.
        
        var notOK: Int
        var secretInput = Data()
        
        // Client side uses EXP(Y,x) | EXP(B,x)
        var exp = Data(capacity: sharedSecretLength)
        
//        curve25519.ScalarMult(&exp, clientKeypair.private.Bytes(), serverPublic.Bytes())
//        notOk |= constantTimeIsZero(exp[:])
//        secretInput.Write(exp[:])
//
//        curve25519.ScalarMult(&exp, clientKeypair.private.Bytes(), idPublic.Bytes())
//        notOk |= constantTimeIsZero(exp[:])
//        secretInput.Write(exp[:])
//
//        keySeed, auth = ntorCommon(secretInput, id, idPublic, clientKeypair.public, serverPublic)
        
        guard let (keySeed, auth) = ntorCommon(secretInput: secretInput, nodeID: nodeID, bPublicKey: idPublicKey, xPublicKey: clientKeypair.publicKey, yPublicKey: serverPublicKey)
        else
        {
            return nil
        }
        
//        return notOk == 0, keySeed, auth
//
        return (keySeed: keySeed, auth: auth)
    }
    
    /*
     // ClientHandshake does the client side of a ntor handshake and returnes
     // status, KEY_SEED, and AUTH.  If status is not true or AUTH does not match
     // the value recieved from the server, the handshake MUST be aborted.
     func ClientHandshake(clientKeypair *Keypair, serverPublic *PublicKey, idPublic *PublicKey, id *NodeID) (ok bool, keySeed *KeySeed, auth *Auth) {
     var notOk int
     var secretInput bytes.Buffer
     
     // Client side uses EXP(Y,x) | EXP(B,x)
     var exp [SharedSecretLength]byte
     curve25519.ScalarMult(&exp, clientKeypair.private.Bytes(),
     serverPublic.Bytes())
     notOk |= constantTimeIsZero(exp[:])
     secretInput.Write(exp[:])
     
     curve25519.ScalarMult(&exp, clientKeypair.private.Bytes(),
     idPublic.Bytes())
     notOk |= constantTimeIsZero(exp[:])
     secretInput.Write(exp[:])
     
     keySeed, auth = ntorCommon(secretInput, id, idPublic,
     clientKeypair.public, serverPublic)
     return notOk == 0, keySeed, auth
     }
     */
    
    func ntorCommon(secretInput: Data, nodeID: Data, bPublicKey: Data, xPublicKey: Data, yPublicKey: Data) -> (keySeed: Data, auth: Data)?
    {
        guard let protoID = Data(base64Encoded: protoIDString)
        else
        {
            print("BUG: Unable to convert protoID String to Data")
            return nil
        }
        
        guard let tKey = Data(base64Encoded: tKeyString)
        else
        {
            print("BUG: Unable to convert tKey String to Data")
            return nil
        }
        
        guard let tVerify = Data(base64Encoded: tVerifyString)
        else
        {
            print("BUG: Unable to convert tVerify String to Data")
            return nil
        }
        
        guard let serverStringAsData = Data(base64Encoded: "Server")
        else
        {
            print("BUG: Unable to convert server String to Data")
            return nil

        }
        
        guard let tMac = Data(base64Encoded: tMacString)
        else
        {
            print("BUG: Unable to convert tMac String to Data")
            return nil
        }
        
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
    
    /*
     func ntorCommon(secretInput bytes.Buffer, id *NodeID, b *PublicKey, x *PublicKey, y *PublicKey) (*KeySeed, *Auth) {
     keySeed := new(KeySeed)
     auth := new(Auth)
     
     // secret_input/auth_input use this common bit, build it once.
     suffix := bytes.NewBuffer(b.Bytes()[:])
     suffix.Write(b.Bytes()[:])
     suffix.Write(x.Bytes()[:])
     suffix.Write(y.Bytes()[:])
     suffix.Write(protoID)
     suffix.Write(id[:])
     
     // At this point secret_input has the 2 exponents, concatenated, append the
     // client/server common suffix.
     secretInput.Write(suffix.Bytes())
     
     // KEY_SEED = H(secret_input, t_key)
     h := hmac.New(sha256.New, tKey)
     h.Write(secretInput.Bytes())
     tmp := h.Sum(nil)
     copy(keySeed[:], tmp)
     
     // verify = H(secret_input, t_verify)
     h = hmac.New(sha256.New, tVerify)
     h.Write(secretInput.Bytes())
     verify := h.Sum(nil)
     
     // auth_input = verify | ID | B | Y | X | PROTOID | "Server"
     authInput := bytes.NewBuffer(verify)
     authInput.Write(suffix.Bytes())
     authInput.Write([]byte("Server"))
     h = hmac.New(sha256.New, tMac)
     h.Write(authInput.Bytes())
     tmp = h.Sum(nil)
     copy(auth[:], tmp)
     
     return keySeed, auth
     }
    */

    /// Returns the number of hours since the UNIX epoch.
    func getEpochHour() -> Int
    {
        let secondsSince1970 = Date().timeIntervalSince1970
        let hoursSince1970 = secondsSince1970/3600
        
        return Int(hoursSince1970)
    }
    
    func encode(_ data: Data) -> Data {
        return data
    }
    
    func decode(_ data: Data) -> Data {
        return data
    }
}

/// Takes an encoded cert string and returns a node id and public key.
func unpack(certString: String) -> (nodeID: Data, publicKey: Data)?
{
    // PrivateKeyLength is the length of a Curve25519 private key.
    let privateKeyLength = 32
    
    // SharedSecretLength is the length of a Curve25519 shared secret.
    let sharedSecretLength = 32
    
    //var nodeID: ntor.NodeID
    //var publicKey: ntor.PublicKey

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
    
    guard let sodiumKeypair = sodium.box.keyPair()
    else
    {
        return nil
    }
    
    //TODO: elligator compression of public key to get representative
    var representative: [Any]?
    
    // Apply the Elligator transform.  This fails ~50% of the time.
    while representative == nil
    {
        representative = Elligator.scalarBaseMult(sodiumKeypair.publicKey)
    }
    
    if let actualRepresentative = representative as? [UInt8]
    {
        let newKeypair = Keypair(publicKey: sodiumKeypair.publicKey, privateKey: sodiumKeypair.secretKey, representative: Data(actualRepresentative))
        return newKeypair
    }
    else
    {
        return nil
    }
    
    // Generate a Curve25519 private key.  Like everyone who does this,
    // run the CSPRNG output through SHA256 for extra tinfoil hattery.
    
/*
     // NewKeypair generates a new Curve25519 keypair, and optionally also generates
     // an Elligator representative of the public key.
     func NewKeypair(elligator bool) (*Keypair, error)
     {
         for
         {
             //Generate keypair

             // Apply the Elligator transform.  This fails ~50% of the time.
             if !extra25519.ScalarBaseMult(keypair.public.Bytes(), keypair.representative.Bytes(), keypair.private.Bytes())
             {
                continue
             }
     
             return keypair, nil
         }
     }
*/
}

func makePacket(data: Data, padLen: Int) -> Data
{
/*
     func (conn *obfs4Conn) makePacket(w io.Writer, pktType uint8, data []byte, padLen uint16) error {
     var pkt [framing.MaximumFramePayloadLength]byte
     
     if len(data)+int(padLen) > maxPacketPayloadLength {
     panic(fmt.Sprintf("BUG: makePacket() len(data) + padLen > maxPacketPayloadLength: %d + %d > %d",
     len(data), padLen, maxPacketPayloadLength))
     }
     
     pkt[0] = pktType
     binary.BigEndian.PutUint16(pkt[1:], uint16(len(data)))
     if len(data) > 0 {
     copy(pkt[3:], data[:])
     }
     copy(pkt[3+len(data):], zeroPadBytes[:padLen])
     
     pktLen := packetOverhead + len(data) + int(padLen)
     
     // Encode the packet in an AEAD frame.
     var frame [framing.MaximumSegmentLength]byte
     frameLen, err := conn.encoder.Encode(frame[:], pkt[:pktLen])
 */
    
    return Data()
}

func findMarkMac(mark: Data, buf: Data, startPos: Int, maxPos: Int, fromTail: Bool) -> Int?
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
    
    if fromTail
    {
        // The server can optimize the search process by only examining the
        // tail of the buffer.  The client can't send valid data past M_C |
        // MAC_C as it does not have the server's public key yet.
        let pos = endPos - (markLength + macLength)
        let responseMAC = buf[pos...pos + markLength]
        if responseMAC != mark
        {
            return nil
        }
        else
        {
            return pos
        }
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

/*
func findMarkMac(mark, buf []byte, startPos, maxPos int, fromTail bool) (pos int) {
    if len(mark) != markLength {
        panic(fmt.Sprintf("BUG: Invalid mark length: %d", len(mark)))
    }
    
    endPos := len(buf)
    if startPos > len(buf) {
        return -1
    }
    if endPos > maxPos {
        endPos = maxPos
    }
    if endPos-startPos < markLength+macLength {
        return -1
    }
    
    if fromTail {
        // The server can optimize the search process by only examining the
        // tail of the buffer.  The client can't send valid data past M_C |
        // MAC_C as it does not have the server's public key yet.
        pos = endPos - (markLength + macLength)
        if !hmac.Equal(buf[pos:pos+markLength], mark) {
            return -1
        }
        
        return
    }
    
    // The client has to actually do a substring search since the server can
    // and will send payload trailing the response.
    //
    // XXX: bytes.Index() uses a naive search, which kind of sucks.
    pos = bytes.Index(buf[startPos:endPos], mark)
    if pos == -1 {
        return -1
    }
    
    // Ensure that there is enough trailing data for the MAC.
    if startPos+pos+markLength+macLength > endPos {
        return -1
    }
    
    // Return the index relative to the start of the slice.
    pos += startPos
    return
}
*/
