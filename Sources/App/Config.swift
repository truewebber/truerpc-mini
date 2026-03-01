import Foundation

/// Reads build-time secrets from the app's Info.plist.
///
/// Keys are injected via `Secrets.xcconfig` and written into `Sources/Info.plist`
/// using `$(VARIABLE)` substitution at build time — never hardcoded in source.
///
/// Note: xcconfig treats `//` as a comment, so the Sentry DSN is split:
/// `SENTRY_DSN_REMAINDER` stores everything after `https://`, and `Info.plist`
/// reconstructs the full URL as `https://$(SENTRY_DSN_REMAINDER)`.
struct Config {
    let amplitudeKey: String
    let sentryDsn: String

    init(amplitudeKey: String, sentryDsn: String) {
        self.amplitudeKey = amplitudeKey
        self.sentryDsn = sentryDsn
    }

    static var fromBundle: Config {
        func read(_ key: String) -> String {
            (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return Config(
            amplitudeKey: read("AmplitudeApiKey"),
            sentryDsn: read("SentryDsn")
        )
    }
}
