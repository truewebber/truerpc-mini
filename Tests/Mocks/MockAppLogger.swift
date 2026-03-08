import Foundation
@testable import TrueRPCMini

/// Spy implementation of AppLogger for testing.
///
/// Captures all logged messages per level for assertion in tests.
public final class MockAppLogger: AppLogger {
    public struct LogEntry: Equatable {
        public let message: String
        public let metadata: [String: String]
    }

    public private(set) var debugMessages: [LogEntry] = []
    public private(set) var infoMessages: [LogEntry] = []
    public private(set) var warningMessages: [LogEntry] = []
    public private(set) var errorMessages: [LogEntry] = []

    public init() {}

    public func debug(_ message: @autoclosure () -> String, metadata: [String: String]) {
        debugMessages.append(LogEntry(message: message(), metadata: metadata))
    }

    public func info(_ message: @autoclosure () -> String, metadata: [String: String]) {
        infoMessages.append(LogEntry(message: message(), metadata: metadata))
    }

    public func warning(_ message: @autoclosure () -> String, metadata: [String: String]) {
        warningMessages.append(LogEntry(message: message(), metadata: metadata))
    }

    public func error(_ message: @autoclosure () -> String, metadata: [String: String]) {
        errorMessages.append(LogEntry(message: message(), metadata: metadata))
    }
}
