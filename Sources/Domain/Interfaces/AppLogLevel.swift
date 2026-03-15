/// Severity levels for `AppLogger`, ordered from lowest to highest.
///
/// Used by `SentryLogger` and other filtered backends to apply a `minLevel` gate.
public enum AppLogLevel: Int, Comparable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: AppLogLevel, rhs: AppLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
