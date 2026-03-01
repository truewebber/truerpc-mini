/// Logging interface used by all Use Cases and Repositories in the Domain layer.
///
/// `@autoclosure` prevents string formatting overhead for filtered-out levels.
/// `metadata` carries structured key-value context for log-backend filtering (e.g. Sentry).
/// Implementations live in the Data layer; call sites use the protocol only.
public protocol AppLogger {
    func debug(_ message: @autoclosure () -> String, metadata: [String: String])
    func info(_ message: @autoclosure () -> String, metadata: [String: String])
    func warning(_ message: @autoclosure () -> String, metadata: [String: String])
    func error(_ message: @autoclosure () -> String, metadata: [String: String])
}

public extension AppLogger {
    func debug(_ message: @autoclosure () -> String) { debug(message(), metadata: [:]) }
    func info(_ message: @autoclosure () -> String) { info(message(), metadata: [:]) }
    func warning(_ message: @autoclosure () -> String) { warning(message(), metadata: [:]) }
    func error(_ message: @autoclosure () -> String) { error(message(), metadata: [:]) }
}
