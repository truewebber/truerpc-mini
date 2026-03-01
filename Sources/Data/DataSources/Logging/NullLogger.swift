/// No-op implementation of `AppLogger` for use in contexts where logging is not needed
/// (e.g., Xcode Previews, default DI fallbacks).
struct NullLogger: AppLogger {
    func debug(_ message: @autoclosure () -> String, metadata: [String: String]) {}
    func info(_ message: @autoclosure () -> String, metadata: [String: String]) {}
    func warning(_ message: @autoclosure () -> String, metadata: [String: String]) {}
    func error(_ message: @autoclosure () -> String, metadata: [String: String]) {}
}
