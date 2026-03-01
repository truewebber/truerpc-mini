import Sentry

/// Real implementation of `SentryLogWriterProtocol` that delegates to `SentrySDK.logger`.
///
/// `import Sentry` is intentionally confined to this file.
/// Requires `SentrySDK.start` to have been called with `options.enableLogs = true`.
struct SentrySDKWriter: SentryLogWriterProtocol {
    func write(level: AppLogLevel, message: String, attributes: [String: Any]) {
        let logger = SentrySDK.logger
        switch level {
        case .debug:   logger.debug(message, attributes: attributes)
        case .info:    logger.info(message, attributes: attributes)
        case .warning: logger.warn(message, attributes: attributes)
        case .error:   logger.error(message, attributes: attributes)
        }
    }
}
