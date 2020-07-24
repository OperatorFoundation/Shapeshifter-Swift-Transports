//
//  LoggerQueueTests.swift
//  LoggerQueueTests
//
//  Created by Mafalda on 7/24/20.
//

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