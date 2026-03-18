import XCTest
@testable import TrueRPCMini

final class OSLoggerTests: XCTestCase {
    // MARK: - Protocol conformance

    func test_osLogger_conformsToAppLogger() {
        let logger: AppLogger = OSLogger(category: "test")
        // Conformance verified at compile time; runtime call confirms instantiation succeeds
        logger.debug("ok")
    }

    // MARK: - Metadata formatting

    func test_format_withEmptyMetadata_returnsEmptyString() {
        let sut = OSLogger(category: "test")

        let result = sut.formatMetadata([:])

        XCTAssertEqual(result, "")
    }

    func test_format_withSingleKey_returnsKeyValuePair() {
        let sut = OSLogger(category: "test")

        let result = sut.formatMetadata(["key": "value"])

        XCTAssertEqual(result, "key=value")
    }

    func test_format_withMultipleKeys_returnsSortedKeyValuePairs() {
        let sut = OSLogger(category: "test")

        let result = sut.formatMetadata(["zebra": "1", "alpha": "2", "middle": "3"])

        XCTAssertEqual(result, "alpha=2 middle=3 zebra=1")
    }

    func test_format_withSpecialCharactersInValues_preservesValues() {
        let sut = OSLogger(category: "test")

        let result = sut.formatMetadata(["url": "https://example.com/path?q=1"])

        XCTAssertEqual(result, "url=https://example.com/path?q=1")
    }
}
