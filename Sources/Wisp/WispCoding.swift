//
//  WispCoding.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 11/3/17.
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
import Logging

import Sodium
import Transmission

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
    let log: Logger
    let secretBoxKey: Data
    let sodium = Sodium()
    var nonce: Nonce
    var drbg: HashDrbg
    
    init?(withKey key: Data, logger: Logger)
    {
        guard key.count == keyMaterialLength
        else
        {
            logger.error("Attempted to initialize WispEncoder with an incorrect full key length of \(key.count) when it should be \(keyMaterialLength)")
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
        self.log = logger
    }
    
    /// Encode encodes a single frame worth of payload and returns the encoded frame.
    mutating func encode(payload: Data) -> Data?
    {
        let payloadLength = payload.count
        
        if maximumFramePayloadLength < payloadLength
        {
            log.error("WispCoding encode error: Invalid payload length.")
            return nil
        }

        guard let encodedBytes = sodium.secretBox.seal(message: payload.bytes, secretKey: secretBoxKey.bytes, nonce: self.nonce.data.bytes) else
        {
            return nil
        }
        
//        log.debug("encoded data: \(encodedBytes)")
//        log.debug("encoded data length: \(encodedBytes.count)")
        
        
        // Obfuscate the length.
        let length = UInt16(encodedBytes.count)
        let obfuscatedLength = obfuscate(length: length)
        let encodedData = Data(encodedBytes)
        
        var frame = Data()
        frame.append(obfuscatedLength)
        frame.append(encodedData)

        return frame
    }
    
    mutating func obfuscate(length: UInt16) -> Data
    {
        let lengthMask = self.drbg.nextBlock().bytes
        var unobfuscatedLength = length.bigEndian
        let lengthData = Data(buffer:UnsafeBufferPointer(start: &unobfuscatedLength, count: 1))
        var obfuscatedLength = Data(count: 2)
        
        obfuscatedLength[0] = lengthData[0] ^ lengthMask[0]
        obfuscatedLength[1] = lengthData[1] ^ lengthMask[1]

        return obfuscatedLength
    }
}

/// Decoder is a frame decoder instance.
struct WispDecoder
{
    let sodium = Sodium()
    let log: Logger
    let secretBoxKey: Data
    
    var nonce: Nonce
    var nextNonce: Nonce?
    var nextLengthInvalid: Bool = false
    var drbg: HashDrbg
    
    /// Creates a new Decoder instance.  It must be supplied a slice containing exactly keyMaterialLength bytes of keying material.
    init?(withKey key: Data, logger: Logger)
    {
        if key.count != keyMaterialLength
        {
            logger.error("BUG: Invalid decoder key length: \(key.count)")
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
        self.log = logger
    }

    /// Decode decodes a stream of data and returns it.
    mutating func decode(network: Transmission.Connection) -> DecodeResult
    {
        // Get the length of the message
        guard let obfsLength = network.read(size: lengthLength)
        else
        {
            return .failed
        }
                
        let unobfsLength = unobfuscate(obfuscatedLength: obfsLength)
        
        if maxFrameLength < unobfsLength || minFrameLength > unobfsLength
        {
            self.nextLengthInvalid = true
        }
        
        guard !nextLengthInvalid
            else
        {
            return .failed
        }
        
        guard let box = network.read(size: Int(unobfsLength))
        else
        {
            return .failed
        }
                
        log.debug("box: \(box.bytes)")
        log.debug("box count: \(box.count)")
        log.debug("secret Key: \(secretBoxKey.bytes)")
        log.debug("secret key count: \(secretBoxKey.count)")
        log.debug("nonce counter: \(nonce.counter)")
        log.debug("nonce secret key: \(nonce.prefix.bytes)")
        
        guard let decodedData = sodium.secretBox.open(authenticatedCipherText: box.bytes, secretKey: secretBoxKey.bytes, nonce: nonce.data.bytes)
            else
        {
            return .failed
        }

        return .success(decodedData: Data(decodedData), leftovers: nil)
    }
    
    mutating func unobfuscate(obfuscatedLength: Data) -> UInt16
    {
        assert(obfuscatedLength.count == 2)
        let lengthMask = self.drbg.nextBlock()
        var unobfuscatedLengthData = Data(count: 2)
        unobfuscatedLengthData[0] = obfuscatedLength[0] ^ lengthMask[0]
        unobfuscatedLengthData[1] = obfuscatedLength[1] ^ lengthMask[1]
        let unobfuscatedLengthInt = toUInt16(data: unobfuscatedLengthData)
        
        log.debug("Unobfuscated a length! \(unobfuscatedLengthInt.bigEndian)")
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
