import XCTest
@testable import TrueRPCMini

final class UpdaterServiceProtocolTests: XCTestCase {
    func test_mockUpdaterService_checkForUpdates_setsCalledFlag() {
        let sut = MockUpdaterService()

        sut.checkForUpdates()

        XCTAssertTrue(sut.checkForUpdatesCalled, "checkForUpdates() must set the called flag")
    }

    func test_mockUpdaterService_checkForUpdates_notCalledByDefault() {
        let sut = MockUpdaterService()

        XCTAssertFalse(sut.checkForUpdatesCalled, "checkForUpdatesCalled must be false before any call")
    }

    func test_mockUpdaterService_canCheckForUpdates_reflectsMockValue_whenFalse() {
        let sut = MockUpdaterService()
        sut.canCheckForUpdatesValue = false

        XCTAssertFalse(sut.canCheckForUpdates)
    }

    func test_mockUpdaterService_canCheckForUpdates_reflectsMockValue_whenTrue() {
        let sut = MockUpdaterService()
        sut.canCheckForUpdatesValue = true

        XCTAssertTrue(sut.canCheckForUpdates)
    }
}
