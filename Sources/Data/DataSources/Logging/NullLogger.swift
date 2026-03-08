/// No-op implementation of `AppLogger` for use in contexts where logging is not needed
/// (e.g., Xcode Previews, default DI fallbacks).
struct NullLogger: AppLogger {
    func debug(_: @autoclosure () -> String, metadata _: [String: String]) {}
    func info(_: @autoclosure () -> String, metadata _: [String: String]) {}
    func warning(_: @autoclosure () -> String, metadata _: [String: String]) {}
    func error(_: @autoclosure () -> String, metadata _: [String: String]) {}
}
