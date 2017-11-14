//
//  WispCoding.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Brandon Wiley on 11/3/17.
//  Copyright © 2017 Operator Foundation. All rights reserved.
//

import Foundation

struct Nonce
{
    let prefix: Data
    var counter: Int
}

struct WispEncoder
{
    let key: Data
    var nonce: Nonce
    
    init(withKey: Data)
    {
        key=withKey
        
        nonce = Nonce(prefix: Data(), counter: 0)
        
/*
         if len(key) != KeyLength {
         panic(fmt.Sprintf("BUG: Invalid encoder key length: %d", len(key)))
         }
         
         encoder := new(Encoder)
         copy(encoder.key[:], key[0:keyLength])
         encoder.nonce.init(key[keyLength : keyLength+noncePrefixLength])
 */
    }
    
    mutating func encode(data: Data) -> Data
    {
        
        return data
    }
}

struct WispDecoder
{
    let key: Data
    var nonce: Nonce
    
    var nextNonce: Data?
    var nextLength: Int?
    var nextLengthInvalid: Bool = false
    
    init(withKey: Data) {
        key=withKey
        
        nonce = Nonce(prefix: Data(), counter: 0)
    }
    
    mutating func decode(data: Data) -> Data {
        /*
         // NewDecoder creates a new Decoder instance.  It must be supplied a slice
         // containing exactly KeyLength bytes of keying material.
         func NewDecoder(key []byte) *Decoder {
         if len(key) != KeyLength {
         panic(fmt.Sprintf("BUG: Invalid decoder key length: %d", len(key)))
         }
         
         decoder := new(Decoder)
         copy(decoder.key[:], key[0:keyLength])
         decoder.nonce.init(key[keyLength : keyLength+noncePrefixLength])
         seed, err := drbg.SeedFromBytes(key[keyLength+noncePrefixLength:])
         if err != nil {
         panic(fmt.Sprintf("BUG: Failed to initialize DRBG: %s", err))
         }
         decoder.drbg, _ = drbg.NewHashDrbg(seed)
         
         return decoder
         }
         
         ...
         
         // Decode decodes a stream of data and returns the length if any.  ErrAgain is
         // a temporary failure, all other errors MUST be treated as fatal and the
         // session aborted.
         func (decoder *Decoder) Decode(data []byte, frames *bytes.Buffer) (int, error) {
         // A length of 0 indicates that we do not know how big the next frame is
         // going to be.
         if decoder.nextLength == 0 {
         // Attempt to pull out the next frame length.
         if lengthLength > frames.Len() {
         return 0, ErrAgain
         }
         
         // Remove the length field from the buffer.
         var obfsLen [lengthLength]byte
         _, err := io.ReadFull(frames, obfsLen[:])
         if err != nil {
         return 0, err
         }
         
         // Derive the nonce the peer used.
         if err = decoder.nonce.bytes(&decoder.nextNonce); err != nil {
         return 0, err
         }
         
         // Deobfuscate the length field.
         length := binary.BigEndian.Uint16(obfsLen[:])
         lengthMask := decoder.drbg.NextBlock()
         length ^= binary.BigEndian.Uint16(lengthMask)
         if maxFrameLength < length || minFrameLength > length {
         // Per "Plaintext Recovery Attacks Against SSH" by
         // Martin R. Albrecht, Kenneth G. Paterson and Gaven J. Watson,
         // there are a class of attacks againt protocols that use similar
         // sorts of framing schemes.
         //
         // While obfs4 should not allow plaintext recovery (CBC mode is
         // not used), attempt to mitigate out of bound frame length errors
         // by pretending that the length was a random valid range as per
         // the countermeasure suggested by Denis Bider in section 6 of the
         // paper.
         
         decoder.nextLengthInvalid = true
         length = uint16(csrand.IntRange(minFrameLength, maxFrameLength))
         }
         decoder.nextLength = length
         }
         
         if int(decoder.nextLength) > frames.Len() {
         return 0, ErrAgain
         }
         
         // Unseal the frame.
         var box [maxFrameLength]byte
         n, err := io.ReadFull(frames, box[:decoder.nextLength])
         if err != nil {
         return 0, err
         }
         out, ok := secretbox.Open(data[:0], box[:n], &decoder.nextNonce, &decoder.key)
         if !ok || decoder.nextLengthInvalid {
         // When a random length is used (on length error) the tag should always
         // mismatch, but be paranoid.
         return 0, ErrTagMismatch
         }
         
         // Clean up and prepare for the next frame.
         decoder.nextLength = 0
         decoder.nonce.counter++
         
         return len(out), nil
         }
         */
        
        return data
    }
}
