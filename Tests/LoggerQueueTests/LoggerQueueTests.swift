//
//  LoggerQueueTests.swift
//  LoggerQueueTests
//
//  Created by Mafalda on 7/24/20.
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

import XCTest
import Logging

@testable import LoggerQueue

class LoggerQueueTests: XCTestCase
{
    /// Swift docs requirement:
    /// When developing your `LogHandler`, please make sure the following test works.
    func testBootstrap() throws
    {
        // your LogHandler might have a different bootstrapping step
        LoggingSystem.bootstrap(LoggerQueue.init)
        var logger1 = Logger(label: "first logger")
        logger1.logLevel = .debug
        logger1[metadataKey: "only-on"] = "first"
        ///
        var logger2 = logger1
        logger2.logLevel = .error                  // this must not override `logger1`'s log level
        logger2[metadataKey: "only-on"] = "second" // this must not override `logger1`'s metadata
        ///
        XCTAssertEqual(.debug, logger1.logLevel)
        XCTAssertEqual(.error, logger2.logLevel)
        XCTAssertEqual("first", logger1[metadataKey: "only-on"])
        XCTAssertEqual("second", logger2[metadataKey: "only-on"])
    }


}
