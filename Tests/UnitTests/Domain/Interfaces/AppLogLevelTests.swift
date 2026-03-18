import XCTest
@testable import TrueRPCMini

final class AppLogLevelTests: XCTestCase {
    // MARK: - Ordering

    func test_appLogLevel_debug_isLessThanInfo() {
        XCTAssertLessThan(AppLogLevel.debug, AppLogLevel.info)
    }

    func test_appLogLevel_info_isLessThanWarning() {
        XCTAssertLessThan(AppLogLevel.info, AppLogLevel.warning)
    }

    func test_appLogLevel_warning_isLessThanError() {
        XCTAssertLessThan(AppLogLevel.warning, AppLogLevel.error)
    }

    func test_appLogLevel_error_isGreaterThanDebug() {
        XCTAssertGreaterThan(AppLogLevel.error, AppLogLevel.debug)
    }

    // MARK: - Equality

    func test_appLogLevel_debug_equalsDebug() {
        XCTAssertEqual(AppLogLevel.debug, AppLogLevel.debug)
    }

    func test_appLogLevel_error_equalsError() {
        XCTAssertEqual(AppLogLevel.error, AppLogLevel.error)
    }

    // MARK: - minLevel guard semantics

    func test_appLogLevel_debugPassesWhenMinLevelIsDebug() {
        XCTAssertGreaterThanOrEqual(AppLogLevel.debug, AppLogLevel.debug)
    }

    func test_appLogLevel_debugBlockedWhenMinLevelIsError() {
        XCTAssertFalse(AppLogLevel.debug >= AppLogLevel.error)
    }

    func test_appLogLevel_errorPassesWhenMinLevelIsError() {
        XCTAssertGreaterThanOrEqual(AppLogLevel.error, AppLogLevel.error)
    }

    func test_appLogLevel_warningBlockedWhenMinLevelIsError() {
        XCTAssertFalse(AppLogLevel.warning >= AppLogLevel.error)
    }
}
