//
//  WispErrors.swift
//  Shapeshifter-Swift-Transports
//
//  Created by Adelita Schule on 12/4/17.
//
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

import Foundation

enum ParseServerHSResult
{
    case success(seed: Data)
    case retry
    case failed
}

enum DecodeResult
{
    case success(decodedData: Data, leftovers: Data?)
    case retry
    case failed
}

enum WispError: Error
{
    case connectionError
    case invalidServerHandshake
    case invalidClientHandshake
    case invalidCertString
    case decoderNotFound
    case decoderFailure
    case connectionClosed
    case invalidResponse
    case serverError
    case serverUnavailable
}
