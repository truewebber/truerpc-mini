import XCTest
@testable import TrueRPCMini

final class SparkleConfigurationTests: XCTestCase {
    // MARK: - Appcast

    func test_infoPlist_containsSUFeedURL() throws {
        let value = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String

        XCTAssertNotNil(value, "Info.plist must declare SUFeedURL for Sparkle appcast discovery")
        XCTAssertFalse(try XCTUnwrap(value?.isEmpty), "SUFeedURL must not be empty")
    }

    func test_infoPlist_SUFeedURL_usesHTTPS() {
        let value = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""

        XCTAssertTrue(value.hasPrefix("https://"), "SUFeedURL must use HTTPS for secure appcast delivery")
    }

    func test_infoPlist_containsSUPublicEDKey() throws {
        let value = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String

        XCTAssertNotNil(value, "Info.plist must declare SUPublicEDKey so Sparkle rejects unsigned artifacts")
        XCTAssertFalse(try XCTUnwrap(value?.isEmpty), "SUPublicEDKey must not be empty")
    }

    // MARK: - Background check schedule

    // Scenario: "available" — Sparkle can discover a new version only when scheduled
    // checks are running on a positive interval.

    func test_infoPlist_SUScheduledCheckInterval_isPresent() {
        let value = Bundle.main.object(forInfoDictionaryKey: "SUScheduledCheckInterval")

        XCTAssertNotNil(
            value,
            "Info.plist must declare SUScheduledCheckInterval so background checks run on a configured schedule")
    }

    func test_infoPlist_SUScheduledCheckInterval_isAtLeastOneHour() {
        let interval = (Bundle.main.object(forInfoDictionaryKey: "SUScheduledCheckInterval") as? NSNumber)?
            .doubleValue ?? 0

        XCTAssertGreaterThanOrEqual(
            interval,
            3600,
            "SUScheduledCheckInterval must be ≥ 3600 s (1 h) to avoid polling too aggressively")
    }

    func test_infoPlist_SUScheduledCheckInterval_isAtMostOneWeek() {
        let interval = (Bundle.main.object(forInfoDictionaryKey: "SUScheduledCheckInterval") as? NSNumber)?
            .doubleValue ?? 0

        XCTAssertLessThanOrEqual(
            interval,
            604_800,
            "SUScheduledCheckInterval must be ≤ 604 800 s (7 days) so users receive updates reasonably quickly")
    }

    // MARK: - Suggestion-only flow

    // Scenario: "update skipped" / "already up-to-date" — SPUStandardUpdaterController
    // with nil updaterDelegate and nil userDriverDelegate preserves Sparkle's default
    // prompt ("Install Update" / "Skip This Version" / "Remind Me Later") and skip
    // persistence (stored in NSUserDefaults under SUSkippedMinorUpdates).
    // No auto-install takes place unless the user explicitly opts in at the OS level.
    //
    // The key that gates forced auto-install is SUAllowsAutomaticUpdates.
    // By default (key absent), Sparkle treats it as YES — meaning the user CAN enable
    // automatic installs in preferences — but the *default* preference value is NO,
    // so installs are never silent unless the user turns it on.
    //
    // We do NOT set SUAllowsAutomaticUpdates = NO because that would also hide
    // the "Automatically check for updates" toggle, preventing background checks entirely.

    func test_infoPlist_SUAllowsAutomaticUpdates_isAbsentOrTrue() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "SUAllowsAutomaticUpdates")

        if let value = raw as? NSNumber {
            XCTAssertTrue(
                value.boolValue,
                "SUAllowsAutomaticUpdates must not be NO — setting it to NO disables background checks")
        } else {
            // Key absent → Sparkle defaults to YES (background checks enabled)
            XCTAssertNil(
                raw,
                "Expected SUAllowsAutomaticUpdates to be absent (Sparkle default YES) or explicitly true")
        }
    }
}
