//
//  ReplicantErrors.swift
//  Replicant
//
//  Created by Adelita Schule on 12/28/18.
//

import Foundation

enum ReplicantError: Error
{
    case noClientPublicKey
    case invalidServerHandshake
    case invalidClientHandshake
    case invalidCertString
    case invalidPort
    case decoderNotFound
    case decoderFailure
    case connectionClosed
    case invalidResponse
    case serverError
    case serverUnavailable
}
