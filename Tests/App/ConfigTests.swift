import XCTest
@testable import TrueRPCMini

final class ConfigTests: XCTestCase {

    // MARK: - Init stores values

    func test_config_init_storesAmplitudeKey() {
        let sut = Config(amplitudeKey: "amp_key_123", sentryDsn: "https://dsn@sentry.io/1")

        XCTAssertEqual(sut.amplitudeKey, "amp_key_123")
    }

    func test_config_init_storesSentryDsn() {
        let sut = Config(amplitudeKey: "amp_key_123", sentryDsn: "https://dsn@sentry.io/1")

        XCTAssertEqual(sut.sentryDsn, "https://dsn@sentry.io/1")
    }

    func test_config_init_withEmptyKeys_storesEmptyStrings() {
        let sut = Config(amplitudeKey: "", sentryDsn: "")

        XCTAssertEqual(sut.amplitudeKey, "")
        XCTAssertEqual(sut.sentryDsn, "")
    }

    // MARK: - fromBundle reads from Info.plist

    func test_config_fromBundle_amplitudeKey_returnsNonEmptyString() {
        // Debug.xcconfig sets AMPLITUDE_API_KEY = dummy, which is injected
        // into Info.plist at build time — never empty.
        XCTAssertFalse(Config.fromBundle.amplitudeKey.isEmpty)
    }

    func test_config_fromBundle_sentryDsn_startsWithHttpsScheme() {
        // Info.plist reconstructs the URL as https://$(SENTRY_DSN_REMAINDER).
        // Debug.xcconfig sets SENTRY_DSN_REMAINDER = dummy-remainder.
        XCTAssertTrue(Config.fromBundle.sentryDsn.hasPrefix("https://"))
    }

    func test_config_fromBundle_trims_whitespace() {
        // Keys from xcconfig sometimes carry trailing newlines on certain
        // Xcode versions — fromBundle must trim before returning.
        let key = Config.fromBundle.amplitudeKey
        XCTAssertEqual(key, key.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
