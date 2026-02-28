import XCTest
@testable import TrueRPCMini

final class UserDefaultsAnalyticsOptOutTests: XCTestCase {

    var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "test.analytics.optout")!
        userDefaults.removePersistentDomain(forName: "test.analytics.optout")
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "test.analytics.optout")
        userDefaults = nil
        super.tearDown()
    }

    func test_analyticsOptOut_whenKeyAbsent_returnsFalse() {
        let value = userDefaults.analyticsOptOut
        XCTAssertFalse(value)
    }

    func test_analyticsOptOut_afterMigration_whenKeyAbsent_returnsTrue() {
        UserDefaults.runAnalyticsOptOutMigration(on: userDefaults)
        let value = userDefaults.analyticsOptOut
        XCTAssertTrue(value)
    }

    func test_analyticsOptOut_writeTrue_reRead_returnsTrue() {
        userDefaults.analyticsOptOut = true
        let value = userDefaults.analyticsOptOut
        XCTAssertTrue(value)
    }

    func test_analyticsOptOut_writeFalse_reRead_returnsFalse() {
        userDefaults.analyticsOptOut = true
        userDefaults.analyticsOptOut = false
        let value = userDefaults.analyticsOptOut
        XCTAssertFalse(value)
    }

    func test_runAnalyticsOptOutMigration_whenKeyExists_doesNotOverwrite() {
        userDefaults.analyticsOptOut = false
        UserDefaults.runAnalyticsOptOutMigration(on: userDefaults)
        XCTAssertFalse(userDefaults.analyticsOptOut)
    }
}
