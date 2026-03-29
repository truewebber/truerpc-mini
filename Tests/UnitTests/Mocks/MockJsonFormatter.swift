import Foundation
import os
@testable import TrueRPCMini

/// Spy/stub implementation of `JsonFormatterProtocol` for unit tests.
///
/// By default behaves as an identity transform (returns input unchanged).
/// Set `formattedResult` to override the return value, or `shouldThrow` to simulate failure.
///
/// Thread-safe via `OSAllocatedUnfairLock` to satisfy `Sendable`.
final class MockJsonFormatter: JsonFormatterProtocol, Sendable {
    private struct Storage {
        var formattedResult: String?
        var shouldThrow: Bool = false
        var formatCallCount: Int = 0
        var lastInput: String?
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    /// When non-nil, `format()` returns this value instead of the input.
    var formattedResult: String? {
        get { storage.withLock { $0.formattedResult } }
        set { storage.withLock { $0.formattedResult = newValue } }
    }

    var shouldThrow: Bool {
        get { storage.withLock { $0.shouldThrow } }
        set { storage.withLock { $0.shouldThrow = newValue } }
    }

    var formatCallCount: Int {
        storage.withLock { $0.formatCallCount }
    }

    var lastInput: String? {
        storage.withLock { $0.lastInput }
    }

    func format(_ json: String) throws -> String {
        storage.withLock {
            $0.formatCallCount += 1
            $0.lastInput = json
        }
        if storage.withLock({ $0.shouldThrow }) {
            throw JsonFormatterError.invalidJSON("mock error")
        }
        return storage.withLock { $0.formattedResult ?? json }
    }
}
