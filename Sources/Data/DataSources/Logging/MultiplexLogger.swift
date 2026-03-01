/// Composite `AppLogger` that dispatches each log entry to all registered backends.
///
/// The `@autoclosure` is evaluated **once** before iterating handlers,
/// preventing redundant string formatting when multiple backends are active.
/// Each handler applies its own filtering (e.g. `SentryLogger.minLevel`) independently.
struct MultiplexLogger: AppLogger {
    private let handlers: [AppLogger]

    init(_ handlers: [AppLogger]) {
        self.handlers = handlers
    }

    func debug(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        handlers.forEach { $0.debug(msg, metadata: metadata) }
    }

    func info(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        handlers.forEach { $0.info(msg, metadata: metadata) }
    }

    func warning(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        handlers.forEach { $0.warning(msg, metadata: metadata) }
    }

    func error(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        handlers.forEach { $0.error(msg, metadata: metadata) }
    }
}
