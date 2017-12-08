//
//  WispCoding.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 11/3/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

/// Package framing implements the obfs4 link framing and cryptography.
//
// The Encoder/Decoder shared secret format is:
//    uint8_t[32] NaCl secretbox key
//    uint8_t[16] NaCl Nonce prefix
//    uint8_t[16] SipHash-2-4 key (used to obfsucate length)
//    uint8_t[8]  SipHash-2-4 IV
//
// The frame format is:
//   uint16_t length (obfsucated, big endian)
//   NaCl secretbox (Poly1305/XSalsa20) containing:
//     uint8_t[16] tag (Part of the secretbox construct)
//     uint8_t[]   payload
//
// The length field is length of the NaCl secretbox XORed with the truncated
// SipHash-2-4 digest ran in OFB mode.
//
//     Initialize K, IV[0] with values from the shared secret.
//     On each packet, IV[n] = H(K, IV[n - 1])
//     mask[n] = IV[n][0:2]
//     obfsLen = length ^ mask[n]
//
// The NaCl secretbox (Poly1305/XSalsa20) nonce format is:
//     uint8_t[24] prefix (Fixed)
//     uint64_t    counter (Big endian)
//
// The counter is initialized to 1, and is incremented on each frame.  Since
// the protocol is designed to be used over a reliable medium, the nonce is not
// transmitted over the wire as both sides of the conversation know the prefix
// and the initial counter value.  It is imperative that the counter does not
// wrap, and sessions MUST terminate before 2^64 frames are sent.
//

import Foundation
import Sodium

struct Nonce
{
    var prefix: Data
    var counter: Int
    
    init(prefix: Data)
    {
        self.counter = 0
        self.prefix = prefix
    }
    
    var data: Data
    {
        mutating get
        {
            counter = counter + 1
            var sData = prefix
            sData.append(UnsafeBufferPointer(start: &counter, count: 1) )
            return sData
        }
    }
}

struct HashDrbg
{
    var sip: Data //hash.Hash64
    var ofb = Data(capacity: siphashSize) // [Size]byte

    // NextBlock returns the next 8 byte DRBG block.
    mutating func nextBlock() -> Data
    {
        let sodium = Sodium()
        self.ofb = sodium.shortHash.hash(message: self.ofb, key: self.sip)!
        return self.ofb
    }
}

struct WispEncoder
{
    let secretBoxKey: Data
    let sodium = Sodium()
    let nonce: Nonce
    var drbg: HashDrbg
    
    init?(withKey key: Data)
    {
        guard key.count == keyMaterialLength
        else
        {
            print("Attempted to initialize WispEncoder with an incorrect full key length: \(key.count)")
            return nil
        }
        
        let secretBoxKey = key[0 ..< keyLength]
        let nonce = Nonce(prefix: key[keyLength ..< keyLength + noncePrefixLength])
        let seed = key[keyLength + noncePrefixLength ..< key.count]
        let sipKey: Data = seed[0 ..< 16]
        let ofb = seed[16 ..< seed.count]
        
        self.secretBoxKey = secretBoxKey
        self.nonce = nonce
        self.drbg = HashDrbg(sip: sipKey, ofb: ofb)
    }
    
    /// Encode encodes a single frame worth of payload and returns the encoded frame.
    // TODO: InvalidPayloadLengthError is recoverable, all other errors MUST be treated as fatal and the session aborted. <-----
    mutating func encode(payload: Data) -> Data?
    {
        let payloadLength = payload.count
        
        if maximumFramePayloadLength < payloadLength
        {
            print("WispCoding encode error: Invalid payload length.")
            return nil
        }
        
        // Nonce counter increases by 1 every time we access the nonce.data property
        // Encrypt and MAC payload.
        
        /// TODO: SecretBox needs to take a nonce <Update API> <<-------------------
        guard let encodedData: Data = sodium.secretBox.seal(message: payload, secretKey: secretBoxKey)
        else
        {
            return nil
        }
        
        // Obfuscate the length.
        let lengthMask = self.drbg.nextBlock()
        var length = encodedData.count.bigEndian
        let lengthData = Data(buffer:UnsafeBufferPointer(start: &length, count: 2))
        
        var obfuscatedLength = Data(capacity: 2)
        obfuscatedLength[0] = lengthData[0] ^ lengthMask[0]
        obfuscatedLength[1] = lengthData[1] ^ lengthMask[1]
        
        var frame = Data()
        frame.append(obfuscatedLength)
        frame.append(encodedData)

        return frame
    }
}

/// Decoder is a frame decoder instance.
struct WispDecoder
{
    let sodium = Sodium()
    let secretBoxKey: Data
    
    var nonce: Nonce
    var nextNonce: Nonce?
    var nextLength: UInt16?
    var nextLengthInvalid: Bool = false
    var drbg: HashDrbg
    
    /// Creates a new Decoder instance.  It must be supplied a slice containing exactly keyMaterialLength bytes of keying material.
    init?(withKey key: Data)
    {
        if key.count != keyMaterialLength
        {
            print("BUG: Invalid decoder key length: \(key.count)")
            return nil
        }
        
        self.secretBoxKey = key[0 ..< keyLength]
        self.nonce = Nonce(prefix: key[keyLength ..< keyLength + noncePrefixLength])
        
        let seed = key[keyLength + noncePrefixLength ..< key.count]
        let sipKey: Data = seed[0 ..< 16]
        let ofb = seed[16 ..< seed.count]
        self.drbg = HashDrbg(sip: sipKey, ofb: ofb)
    }

    /// Decode decodes a stream of data and returns it.
    mutating func decode(framesBuffer: Data) -> DecodeResult
    {
        // ErrAgain is a temporary failure, all other errors MUST be treated as fatal and the session aborted.
        // A length of 0 indicates that we do not know how big the next frame is going to be.
        if nextLength == 0
        {
            // Attempt to pull out the next frame length.
            if lengthLength > framesBuffer.count
            {
                // If the frame buffer only has one bite, we need to wait for another byte.
                /// ErrAgain
                return .retry
            }
            
            // Remove the length field from the buffer.
            let obfsLength = framesBuffer[0 ..< lengthLength]
            
            // Deobfuscate the length field.
            var obfuscatedLengthInt = UInt16(obfsLength.count.bigEndian)
            let lengthMask = self.drbg.nextBlock()
            var obfuscatedLengthData = Data(buffer:UnsafeBufferPointer(start: &obfuscatedLengthInt, count: 2))
            var unobfuscatedLengthData = Data(capacity: 2)
            unobfuscatedLengthData[0] = obfuscatedLengthData[0] ^ lengthMask[0]
            unobfuscatedLengthData[1] = obfuscatedLengthData[1] ^ lengthMask[1]
            nextLength = unobfuscatedLengthData.withUnsafeBytes{$0.pointee}
            
            if maxFrameLength < nextLength! || minFrameLength > nextLength!
            {
                /*
                Per "Plaintext Recovery Attacks Against SSH"
                by Martin R. Albrecht, Kenneth G. Paterson and Gaven J. Watson,
                there are a class of attacks againt protocols
                that use similar sorts of framing schemes.
                
                While obfs4 should not allow plaintext recovery (CBC mode is not used),
                attempt to mitigate out of bound frame length errors
                by pretending that the length was a random valid range as per
                the countermeasure suggested by Denis Bider in section 6 of the paper.
                */
                
                self.nextLengthInvalid = true
                nextLength = random(minFrameLength ..< maxFrameLength + 1)
            }
            
            if nextLength! > framesBuffer.count
            {
                /// ErrAgain
                // We expected more data than we got!
                return .retry
            }
            
            /// Unseal the frame.
            let box = framesBuffer[UInt16(lengthLength) ..< nextLength!]
            let leftovers = framesBuffer[lengthLength + Int(nextLength!) ..< framesBuffer.count]
            
            guard let decodedData = sodium.secretBox.open(authenticatedCipherText: box, secretKey: secretBoxKey, nonce: nonce.data)
            else
            {
                return .failed
            }
            
            guard !nextLengthInvalid
            else
            {
                return .failed
            }
            
            /// Clean up and prepare for the next frame.
            nextLength = nil
            
            return .success(decodedData: decodedData, leftovers: leftovers)
        }
        
        return .failed
    }
    
    func random(_ range:Range<Int>) -> UInt16
    {
        return UInt16(range.lowerBound + Int(arc4random_uniform(UInt32(range.upperBound - range.lowerBound))))
    }
}
