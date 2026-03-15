import Foundation
import os
@testable import TrueRPCMini

/// Spy implementation of AppLogger for testing.
///
/// Thread-safe via OSAllocatedUnfairLock so it satisfies Sendable without @unchecked.
/// Captures all logged messages per level for assertion in tests.
public final class MockAppLogger: AppLogger, Sendable {
    public struct LogEntry: Equatable, Sendable {
        public let message: String
        public let metadata: [String: String]
    }

    private struct Storage {
        var debugMessages: [LogEntry] = []
        var infoMessages: [LogEntry] = []
        var warningMessages: [LogEntry] = []
        var errorMessages: [LogEntry] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    public var debugMessages: [LogEntry] {
        storage.withLock { $0.debugMessages }
    }

    public var infoMessages: [LogEntry] {
        storage.withLock { $0.infoMessages }
    }

    public var warningMessages: [LogEntry] {
        storage.withLock { $0.warningMessages }
    }

    public var errorMessages: [LogEntry] {
        storage.withLock { $0.errorMessages }
    }

    public init() {}

    public func debug(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        storage.withLock { $0.debugMessages.append(LogEntry(message: msg, metadata: metadata)) }
    }

    public func info(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        storage.withLock { $0.infoMessages.append(LogEntry(message: msg, metadata: metadata)) }
    }

    public func warning(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        storage.withLock { $0.warningMessages.append(LogEntry(message: msg, metadata: metadata)) }
    }

    public func error(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        storage.withLock { $0.errorMessages.append(LogEntry(message: msg, metadata: metadata)) }
    }

    public func reset() {
        storage.withLock {
            $0.debugMessages = []
            $0.infoMessages = []
            $0.warningMessages = []
            $0.errorMessages = []
        }
    }
}
