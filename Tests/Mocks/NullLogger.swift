import Foundation
@testable import TrueRPCMini

/// No-op implementation of `AppLogger` for tests that do not assert on log output.
public struct NullLogger: AppLogger {
    public init() {}

    public func debug(_ message: @autoclosure () -> String, metadata: [String: String]) {}
    public func info(_ message: @autoclosure () -> String, metadata: [String: String]) {}
    public func warning(_ message: @autoclosure () -> String, metadata: [String: String]) {}
    public func error(_ message: @autoclosure () -> String, metadata: [String: String]) {}
}
