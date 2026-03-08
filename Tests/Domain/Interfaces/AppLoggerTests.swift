import XCTest
@testable import TrueRPCMini

final class AppLoggerTests: XCTestCase {
    // MARK: - MockAppLogger spy captures all log levels

    func test_mockAppLogger_debug_capturesMessageAndMetadata() {
        let mock = MockAppLogger()

        mock.debug("debug message", metadata: ["key": "value"])

        XCTAssertEqual(mock.debugMessages.count, 1)
        XCTAssertEqual(mock.debugMessages[0].message, "debug message")
        XCTAssertEqual(mock.debugMessages[0].metadata, ["key": "value"])
    }

    func test_mockAppLogger_info_capturesMessageAndMetadata() {
        let mock = MockAppLogger()

        mock.info("info message", metadata: ["env": "test"])

        XCTAssertEqual(mock.infoMessages.count, 1)
        XCTAssertEqual(mock.infoMessages[0].message, "info message")
        XCTAssertEqual(mock.infoMessages[0].metadata, ["env": "test"])
    }

    func test_mockAppLogger_warning_capturesMessageAndMetadata() {
        let mock = MockAppLogger()

        mock.warning("warning message", metadata: ["component": "repo"])

        XCTAssertEqual(mock.warningMessages.count, 1)
        XCTAssertEqual(mock.warningMessages[0].message, "warning message")
        XCTAssertEqual(mock.warningMessages[0].metadata, ["component": "repo"])
    }

    func test_mockAppLogger_error_capturesMessageAndMetadata() {
        let mock = MockAppLogger()

        mock.error("error message", metadata: ["code": "404"])

        XCTAssertEqual(mock.errorMessages.count, 1)
        XCTAssertEqual(mock.errorMessages[0].message, "error message")
        XCTAssertEqual(mock.errorMessages[0].metadata, ["code": "404"])
    }

    // MARK: - Convenience overloads (no metadata)

    func test_mockAppLogger_debug_convenienceOverload_usesEmptyMetadata() {
        let mock = MockAppLogger()

        mock.debug("simple debug")

        XCTAssertEqual(mock.debugMessages.count, 1)
        XCTAssertEqual(mock.debugMessages[0].message, "simple debug")
        XCTAssertEqual(mock.debugMessages[0].metadata, [:])
    }

    func test_mockAppLogger_info_convenienceOverload_usesEmptyMetadata() {
        let mock = MockAppLogger()

        mock.info("simple info")

        XCTAssertEqual(mock.infoMessages.count, 1)
        XCTAssertEqual(mock.infoMessages[0].metadata, [:])
    }

    func test_mockAppLogger_warning_convenienceOverload_usesEmptyMetadata() {
        let mock = MockAppLogger()

        mock.warning("simple warning")

        XCTAssertEqual(mock.warningMessages.count, 1)
        XCTAssertEqual(mock.warningMessages[0].metadata, [:])
    }

    func test_mockAppLogger_error_convenienceOverload_usesEmptyMetadata() {
        let mock = MockAppLogger()

        mock.error("simple error")

        XCTAssertEqual(mock.errorMessages.count, 1)
        XCTAssertEqual(mock.errorMessages[0].metadata, [:])
    }

    // MARK: - MockAppLogger accumulates multiple calls

    func test_mockAppLogger_capturesMultipleCallsPerLevel() {
        let mock = MockAppLogger()

        mock.info("first")
        mock.info("second")
        mock.info("third")

        XCTAssertEqual(mock.infoMessages.count, 3)
        XCTAssertEqual(mock.infoMessages[0].message, "first")
        XCTAssertEqual(mock.infoMessages[2].message, "third")
    }

    func test_mockAppLogger_differentLevelsAreIndependent() {
        let mock = MockAppLogger()

        mock.debug("d")
        mock.info("i")
        mock.warning("w")
        mock.error("e")

        XCTAssertEqual(mock.debugMessages.count, 1)
        XCTAssertEqual(mock.infoMessages.count, 1)
        XCTAssertEqual(mock.warningMessages.count, 1)
        XCTAssertEqual(mock.errorMessages.count, 1)
    }

    // MARK: - NullLogger produces no side effects

    func test_nullLogger_debug_doesNotThrow() {
        let logger: AppLogger = NullLogger()
        logger.debug("ignored", metadata: ["k": "v"])
        // No assertions needed — test passes if no crash/side-effect
    }

    func test_nullLogger_info_doesNotThrow() {
        let logger: AppLogger = NullLogger()
        logger.info("ignored")
    }

    func test_nullLogger_warning_doesNotThrow() {
        let logger: AppLogger = NullLogger()
        logger.warning("ignored")
    }

    func test_nullLogger_error_doesNotThrow() {
        let logger: AppLogger = NullLogger()
        logger.error("ignored", metadata: ["err": "oops"])
    }
}
