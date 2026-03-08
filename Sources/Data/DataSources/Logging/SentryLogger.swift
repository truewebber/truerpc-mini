import Foundation

/// Internal abstraction over the Sentry logging sink.
///
/// Allows replacing real Sentry calls with a mock in unit tests.
protocol SentryLogWriterProtocol {
    func write(level: AppLogLevel, message: String, attributes: [String: Any])
}

/// `AppLogger` backend that forwards log entries to Sentry Structured Logs.
///
/// Only entries at or above `minLevel` are forwarded. Default `minLevel` is `.error`
/// so debug/info noise is filtered out in production (wired by `MultiplexLogger`).
/// `import Sentry` is confined to `SentrySDKWriter` — this file stays SDK-free.
struct SentryLogger: AppLogger {
    let minLevel: AppLogLevel
    private let writer: SentryLogWriterProtocol

    init(minLevel: AppLogLevel = .error, writer: SentryLogWriterProtocol = SentrySDKWriter()) {
        self.minLevel = minLevel
        self.writer = writer
    }

    func debug(_ message: @autoclosure () -> String, metadata: [String: String]) {
        guard minLevel <= .debug else { return }

        writer.write(level: .debug, message: message(), attributes: metadata)
    }

    func info(_ message: @autoclosure () -> String, metadata: [String: String]) {
        guard minLevel <= .info else { return }

        writer.write(level: .info, message: message(), attributes: metadata)
    }

    func warning(_ message: @autoclosure () -> String, metadata: [String: String]) {
        guard minLevel <= .warning else { return }

        writer.write(level: .warning, message: message(), attributes: metadata)
    }

    func error(_ message: @autoclosure () -> String, metadata: [String: String]) {
        guard minLevel <= .error else { return }

        writer.write(level: .error, message: message(), attributes: metadata)
    }
}
