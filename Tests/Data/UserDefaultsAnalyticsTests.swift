import XCTest
@testable import TrueRPCMini

final class UserDefaultsAnalyticsTests: XCTestCase {

    private let suiteName = "com.truerpc.tests.AnalyticsTests"
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        super.tearDown()
    }

    // MARK: - analyticsIsEnabled

    func test_analyticsIsEnabled_defaultValue_isFalse() {
        XCTAssertFalse(userDefaults.analyticsIsEnabled)
    }

    func test_analyticsIsEnabled_whenSetToTrue_returnsTrue() {
        userDefaults.analyticsIsEnabled = true

        XCTAssertTrue(userDefaults.analyticsIsEnabled)
    }

    func test_analyticsIsEnabled_whenSetToFalse_returnsFalse() {
        userDefaults.analyticsIsEnabled = true
        userDefaults.analyticsIsEnabled = false

        XCTAssertFalse(userDefaults.analyticsIsEnabled)
    }

    // MARK: - runAnalyticsMigration

    func test_runAnalyticsMigration_whenNoValueStored_setsEnabledToTrue() {
        UserDefaults.runAnalyticsMigration(on: userDefaults)

        XCTAssertTrue(userDefaults.analyticsIsEnabled)
    }

    func test_runAnalyticsMigration_whenValueAlreadyTrue_doesNotChange() {
        userDefaults.analyticsIsEnabled = true

        UserDefaults.runAnalyticsMigration(on: userDefaults)

        XCTAssertTrue(userDefaults.analyticsIsEnabled)
    }

    func test_runAnalyticsMigration_whenValueAlreadyFalse_doesNotOverride() {
        userDefaults.analyticsIsEnabled = false

        UserDefaults.runAnalyticsMigration(on: userDefaults)

        XCTAssertFalse(userDefaults.analyticsIsEnabled)
    }
}
