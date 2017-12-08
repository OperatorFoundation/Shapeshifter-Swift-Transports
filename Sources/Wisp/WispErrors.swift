//
//  WispErrors.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Adelita Schule on 12/4/17.
//

import Foundation

enum ParseServerHSResult
{
    case success(seed: Data)
    case retry
    case failed
}

enum DecodeResult
{
    case success(decodedData: Data, leftovers: Data)
    case retry
    case failed
}

enum WispError: Error
{
    case connectionError
    case invalidServerHandshake
    case invalidCertString
    case decoderNotFound
    case decoderFailure
    case connectionClosed
    case invalidResponse
    case serverError
    case serverUnavailable
}
