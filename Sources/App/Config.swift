import Foundation

/// Reads build-time secrets from the app's Info.plist.
///
/// Keys are injected via xcconfig (`Secrets.xcconfig`) and surfaced through
/// `INFOPLIST_KEY_*` build settings — never hardcoded in source.
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
