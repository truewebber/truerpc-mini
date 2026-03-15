import XCTest
@testable import TrueRPCMini

final class SparkleUpdaterServiceTests: XCTestCase {
    private var mockUpdating: MockSparkleUpdating!
    private var sut: SparkleUpdaterService!

    override func setUp() {
        super.setUp()
        mockUpdating = MockSparkleUpdating()
        sut = SparkleUpdaterService(updater: mockUpdating)
    }

    override func tearDown() {
        sut = nil
        mockUpdating = nil
        super.tearDown()
    }

    func test_checkForUpdates_delegatesToSparkleUpdating() {
        sut.checkForUpdates()

        XCTAssertTrue(
            mockUpdating.checkForUpdatesCalled,
            "checkForUpdates() must delegate to the underlying SparkleUpdating")
    }

    func test_checkForUpdates_doesNotCallTwice_whenCalledOnce() {
        sut.checkForUpdates()

        XCTAssertEqual(mockUpdating.checkForUpdatesCallCount, 1)
    }

    func test_canCheckForUpdates_reflectsUpdaterValue_whenFalse() {
        mockUpdating.canCheckForUpdatesValue = false

        XCTAssertFalse(sut.canCheckForUpdates)
    }

    func test_canCheckForUpdates_reflectsUpdaterValue_whenTrue() {
        mockUpdating.canCheckForUpdatesValue = true

        XCTAssertTrue(sut.canCheckForUpdates)
    }

    func test_conformsToUpdaterServiceProtocol() {
        XCTAssertTrue(sut is any UpdaterServiceProtocol)
    }
}

// MARK: - Test Double

final class MockSparkleUpdating: SparkleUpdating {
    var checkForUpdatesCalled: Bool {
        checkForUpdatesCallCount > 0
    }

    var checkForUpdatesCallCount = 0
    var canCheckForUpdatesValue = false

    var canCheckForUpdates: Bool {
        canCheckForUpdatesValue
    }

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
    }
}
