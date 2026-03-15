import XCTest
@testable import TrueRPCMini

final class SparkleConfigurationTests: XCTestCase {
    func test_infoPlist_containsSUFeedURL() {
        let value = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String

        XCTAssertNotNil(value, "Info.plist must declare SUFeedURL for Sparkle appcast discovery")
        XCTAssertFalse(value!.isEmpty, "SUFeedURL must not be empty")
    }

    func test_infoPlist_SUFeedURL_usesHTTPS() {
        let value = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""

        XCTAssertTrue(value.hasPrefix("https://"), "SUFeedURL must use HTTPS for secure appcast delivery")
    }

    func test_infoPlist_containsSUPublicEDKey() {
        let value = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String

        XCTAssertNotNil(value, "Info.plist must declare SUPublicEDKey so Sparkle rejects unsigned artifacts")
        XCTAssertFalse(value!.isEmpty, "SUPublicEDKey must not be empty")
    }
}
