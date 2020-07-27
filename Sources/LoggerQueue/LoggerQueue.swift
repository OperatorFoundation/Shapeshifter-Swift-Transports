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

import Logging
import SwiftQueue

public struct LoggerQueue
{
    public var logLevel: Logger.Level
    public var metadata: Logger.Metadata
    public let queue: Queue<LoggerQueueMessage>
    
    public init(label: String)
    {
        // For our purposes, critical logLevel is the same as turning logging off.
        logLevel = .critical
        metadata = [:]
        queue = Queue<LoggerQueueMessage>()
    }
}

extension LoggerQueue: LogHandler
{
    public subscript(metadataKey key: String) -> Logger.Metadata.Value?
    {
        get { return metadata[key] }
        set(newValue) { metadata[key] = newValue }
    }
    
    public func log(level: Logger.Level,
            message: Logger.Message,
            metadata: Logger.Metadata?,
            source: String,
            file: String,
            function: String,
            line: UInt)
    {
        let queueMessage = LoggerQueueMessage(level: level,
                                              message: message,
                                              metadata: metadata,
                                              source: source,
                                              file: file,
                                              function: function,
                                              line: line)
        queue.enqueue(queueMessage)
    }
    
    public func dequeue() -> String?
    {
        guard let message = queue.dequeue()
            else { return nil }
        
        return "\(message.message)"
    }
}

public struct LoggerQueueMessage
{
    let level: Logger.Level
    let message: Logger.Message
    let metadata: Logger.Metadata?
    let source: String
    let file: String
    let function: String
    let line: UInt
}
