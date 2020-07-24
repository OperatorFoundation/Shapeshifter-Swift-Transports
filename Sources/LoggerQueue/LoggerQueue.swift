
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
