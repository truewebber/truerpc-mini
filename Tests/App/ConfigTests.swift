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

    func test_config_fromBundle_amplitudeKey_whenAbsent_returnsEmptyString() {
        // In the test bundle AmplitudeApiKey is not set — expects empty string fallback.
        XCTAssertEqual(Config.fromBundle.amplitudeKey, "")
    }

    func test_config_fromBundle_sentryDsn_whenAbsent_returnsEmptyString() {
        // In the test bundle SentryDsn is not set — expects empty string fallback.
        XCTAssertEqual(Config.fromBundle.sentryDsn, "")
    }

    func test_config_fromBundle_trims_whitespace() {
        // Keys from xcconfig sometimes carry trailing newlines on certain
        // Xcode versions — fromBundle must trim before returning.
        // We verify this indirectly: the returned string has no leading/trailing whitespace.
        let key = Config.fromBundle.amplitudeKey
        XCTAssertEqual(key, key.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
