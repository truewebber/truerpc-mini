import Foundation
import os

/// `AppLogger` implementation backed by Apple Unified Logging (`os.Logger`).
///
/// All messages are logged with `privacy: .public` so they appear unredacted
/// in Console.app. Pass a `category` per module (e.g. `"proto"`, `"request"`)
/// to enable per-category filtering in Console.app.
struct OSLogger: AppLogger {
    private let logger: os.Logger

    init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "com.truewebber",
        category: String)
    {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        let meta = formatMetadata(metadata)
        logger.debug("\(msg, privacy: .public) \(meta, privacy: .public)")
    }

    func info(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        let meta = formatMetadata(metadata)
        logger.info("\(msg, privacy: .public) \(meta, privacy: .public)")
    }

    func warning(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        let meta = formatMetadata(metadata)
        logger.warning("\(msg, privacy: .public) \(meta, privacy: .public)")
    }

    func error(_ message: @autoclosure () -> String, metadata: [String: String]) {
        let msg = message()
        let meta = formatMetadata(metadata)
        logger.error("\(msg, privacy: .public) \(meta, privacy: .public)")
    }

    /// Formats metadata as sorted `key=value` pairs joined by spaces.
    func formatMetadata(_ metadata: [String: String]) -> String {
        metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
    }
}
