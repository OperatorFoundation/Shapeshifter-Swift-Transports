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
    var sip: Data
    var ofb = Data(capacity: siphashSize)

    init(sip: Data, ofb: Data)
    {
        assert(sip.count == 16)
        self.sip = sip
        
        assert(ofb.count == 8)
        self.ofb = ofb
    }
    
    /// NextBlock returns the next 8 byte DRBG block.
    mutating func nextBlock() -> Data
    {
        let sodium = Sodium()
        guard let ofbBytes = sodium.shortHash.hash(message: self.ofb.bytes, key: self.sip.bytes), ofbBytes.count == siphashSize
        else
        {
            print("Error getting next block, sodium hash failed or was the wrong size.")
            return Data()
        }
        
        self.ofb = Data(ofbBytes)
        return self.ofb[0 ..< 8]
    }
}

struct WispEncoder
{
    let secretBoxKey: Data
    let sodium = Sodium()
    var nonce: Nonce
    var drbg: HashDrbg
    
    init?(withKey key: Data)
    {
        guard key.count == keyMaterialLength
        else
        {
            print("Attempted to initialize WispEncoder with an incorrect full key length of \(key.count) when it should be \(keyMaterialLength)")
            return nil
        }
        
        let secretBoxKey = Data(key[0 ..< keyLength])
        let nonce = Nonce(prefix: Data(key[keyLength ..< keyLength + noncePrefixLength]))
        let seed = Data(key[keyLength + noncePrefixLength ..< key.count])
        let sipKey = Data(seed[0 ..< 16])
        let ofb = Data(seed[16 ..< seed.count])
        
        self.secretBoxKey = secretBoxKey
        self.nonce = nonce
        self.drbg = HashDrbg(sip: sipKey, ofb: ofb)
    }
    
    /// Encode encodes a single frame worth of payload and returns the encoded frame.
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
//
//        print("encoder secret key: \(secretBoxKey.bytes)")
//        print("encoder key length: \(secretBoxKey.count)")
//        print("encoder nonce counter: \(self.nonce.counter)")
//        print("encoder nonce key: \(nonce.prefix.count)")
        
//        guard let encodedBytes = sodium.secretBox.seal(message: payload, secretKey: secretBoxKey, nonce: self.nonce.data)
        guard let encodedBytes = sodium.secretBox.seal(message: payload.bytes, secretKey: secretBoxKey.bytes, nonce: self.nonce.data.bytes)
        else
        {
            return nil
        }
        
//        print("encoded data: \(encodedBytes)")
//        print("encoded data length: \(encodedBytes.count)")
        
        
        // Obfuscate the length.
        let length = UInt16(encodedBytes.count)
        let obfuscatedLength = obfuscate(length: length)
        let encodedData = Data(bytes: encodedBytes)
        
        var frame = Data()
        frame.append(obfuscatedLength)
        frame.append(encodedData)

        return frame
    }
    
    mutating func obfuscate(length: UInt16) -> Data
    {
        //print("\nReceived a length to obfuscate: \(length)")
        // Obfuscate the length.
        let lengthMask = self.drbg.nextBlock().bytes
        //print("lengthMask: \(lengthMask)")
        var unobfuscatedLength = length.bigEndian
        let lengthData = Data(buffer:UnsafeBufferPointer(start: &unobfuscatedLength, count: 1))
        
        var obfuscatedLength = Data(count: 2)
        obfuscatedLength[0] = lengthData[0] ^ lengthMask[0]
        obfuscatedLength[1] = lengthData[1] ^ lengthMask[1]
        
//        var obfuscatedLength = Data()
//        let first = lengthData[0] ^ lengthMask[0]
//        let second = lengthData[1] ^ lengthMask[1]
//        obfuscatedLength.append(first)
//        obfuscatedLength.append(second)
        
        //print("Obfuscated a length: \(length)\n")
        return obfuscatedLength
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
        let secretBoxKey = Data(key[0 ..< keyLength])
        let nonce = Nonce(prefix: Data(key[keyLength ..< keyLength + noncePrefixLength]))
        let seed = Data(key[keyLength + noncePrefixLength ..< key.count])
        let sipKey = Data(seed[0 ..< 16])
        let ofb = Data(seed[16 ..< seed.count])
        
        self.secretBoxKey = secretBoxKey
        self.nonce = nonce
        self.drbg = HashDrbg(sip: sipKey, ofb: ofb)
    }

    /// Decode decodes a stream of data and returns it.
    mutating func decode(framesBuffer: Data) -> DecodeResult
    {
        // A length of nil indicates that we do not know how big the next frame is going to be.
        if nextLength == nil
        {
            // Attempt to pull out the next frame length.
            if lengthLength > framesBuffer.count
            {
                // If the frame buffer only has one bite, we need to wait for another byte.
                // ErrAgain
                return .retry
            }
        
        // Remove the length field from the buffer.
        let obfsLength = framesBuffer[0 ..< lengthLength]
        let unobfsLength = unobfuscate(obfuscatedLength: obfsLength)
        nextLength = unobfsLength
            
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
                nextLength = random(inRange: minFrameLength ..< maxFrameLength + 1)
            }
        }
        
        guard nextLength! <= framesBuffer.count + 2
        else
        {
            // ErrAgain
            print("Decode error, next length: \(nextLength!) is greater than the buffer \(framesBuffer.count). We expected more data than we got!")
            return .retry
        }
        
        // Unseal the frame.
        let box = framesBuffer[UInt16(lengthLength) ..< nextLength! + 2]
        assert(UInt16(box.count) == nextLength)
        
        var leftovers: Data?
        if framesBuffer.count > nextLength! + 2
        {
            leftovers = framesBuffer[lengthLength + Int(nextLength! + 2) ..< framesBuffer.count]
        }
        
        print("box: \(box.bytes)")
        print("box count: \(box.count)")
        print("secret Key: \(secretBoxKey.bytes)")
        print("secret key count: \(secretBoxKey.count)")
        print("nonce counter: \(nonce.counter)")
        print("nonce secret key: \(nonce.prefix.bytes)")
        
        guard let decodedData = sodium.secretBox.open(authenticatedCipherText: box.bytes, secretKey: secretBoxKey.bytes, nonce: nonce.data.bytes)
            else
        {
            nextLength = nil
            return .failed
        }
        
        guard !nextLengthInvalid
            else
        {
            nextLength = nil
            return .failed
        }
        
        // Clean up and prepare for the next frame.
        nextLength = nil
        
        return .success(decodedData: Data(bytes: decodedData), leftovers: leftovers)
    }
    
    mutating func unobfuscate(obfuscatedLength: Data) -> UInt16
    {
        assert(obfuscatedLength.count == 2)
        let lengthMask = self.drbg.nextBlock()
        var unobfuscatedLengthData = Data(count: 2)
        unobfuscatedLengthData[0] = obfuscatedLength[0] ^ lengthMask[0]
        unobfuscatedLengthData[1] = obfuscatedLength[1] ^ lengthMask[1]
        let unobfuscatedLengthInt = toUInt16(data: unobfuscatedLengthData)
        
        print("Unobfuscated a length! \(unobfuscatedLengthInt.bigEndian)")
        return unobfuscatedLengthInt.bigEndian //This is actually converting to little endian
    }
    
    func toUInt16(data: Data) -> UInt16
    {
        let value: UInt16 = data.withUnsafeBytes {
            (ptr: UnsafePointer<UInt16>) -> UInt16 in
            return ptr.pointee
        }
        
        return value
    }
    
    func random(inRange range:Range<Int>) -> UInt16
    {
        return UInt16(range.lowerBound + Int(arc4random_uniform(UInt32(range.upperBound - range.lowerBound))))
    }
}
