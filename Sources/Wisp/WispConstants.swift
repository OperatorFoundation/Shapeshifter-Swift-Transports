//
//  WispConstants.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Adelita Schule on 11/29/17.
//

import Foundation

/// MaximumSegmentLength is the length of the largest possible segment including overhead.
let maximumSegmentLength = 1500 - (40 + 12)
let secretboxOverhead = 16

/// FrameOverhead is the length of the framing overhead.
let frameOverhead = lengthLength + secretboxOverhead

/// MaximumFramePayloadLength is the length of the maximum allowed payload per frame.
let maximumFramePayloadLength = maximumSegmentLength - frameOverhead

/// KeyLength is the length of the Encoder/Decoder secret key.
let keyMaterialLength = keyLength + noncePrefixLength + seedLength

/// Size is the length of the HashDrbg output.
let siphashSize = 8

/// SeedLength is the length of the HashDrbg seed.
let seedLength = 16 + siphashSize

let maxFrameLength = maximumSegmentLength - lengthLength
let minFrameLength = frameOverhead - lengthLength
let keyLength = 32
let noncePrefixLength = 16
let nonceCounterLength = 8
let nonceLength = noncePrefixLength + nonceCounterLength
let lengthLength = 2

/// PublicKeyLength is the length of a Curve25519 public key.
let publicKeyLength = 32
let certLength = nodeIDLength + publicKeyLength
let markLength = sha256Size/2
let nodeIDLength = 20
let certSuffix = "=="
let sha256Size = 32

/// Handshake Constants
let seedPacketPayloadLength = seedLength
let packetOverhead = 3

/// RepresentativeLength is the length of an Elligator representative.
let representativeLength = 32
let serverMinPadLength = 0
let maxHandshakeLength = 8192
let macLength  = sha256Size/2

/// SharedSecretLength is the length of a Curve25519 shared secret.
let sharedSecretLength = 32

/// AuthLength is the length of the derived AUTH.
let authLength = sha256Size

/// KeySeedLength is the length of the derived KEY_SEED.
let keySeedLength = sha256Size

let serverMaxPadLength = maxHandshakeLength - (serverMinHandshakeLength + inlineSeedFrameLength)
let clientMinHandshakeLength = representativeLength + markLength + macLength
let clientMinPadLength = (serverMinHandshakeLength + inlineSeedFrameLength) - clientMinHandshakeLength
let clientMaxPadLength = maxHandshakeLength - clientMinHandshakeLength
let serverMinHandshakeLength = representativeLength + authLength + markLength + macLength
let inlineSeedFrameLength = frameOverhead + packetOverhead + seedPacketPayloadLength

let protoIDString = "ntor-curve25519-sha256-1" // Data(base64Encoded: "ntor-curve25519-sha256-1")
let tMacString = protoIDString + ":mac" // append(protoID, []byte(":mac")...)
let tKeyString = protoIDString + ":key_extract" // append(protoID, []byte(":key_extract")...)
let tVerifyString = protoIDString + ":key_verify" // append(protoID, []byte(":key_verify")...)
let mExpandString = protoIDString + ":key_expand" // append(protoID, []byte(":key_expand")...)
