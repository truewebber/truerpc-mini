import XCTest
@testable import TrueRPCMini

@MainActor
final class UpdaterViewModelTests: XCTestCase {
    private var sut: UpdaterViewModel!
    private var mockService: MockUpdaterService!

    override func setUp() {
        super.setUp()
        mockService = MockUpdaterService()
    }

    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }

    // MARK: - Init

    func test_init_canCheckForUpdates_isFalse_whenServiceReturnsFalse() {
        mockService.canCheckForUpdatesValue = false
        sut = UpdaterViewModel(updaterService: mockService)

        XCTAssertFalse(sut.canCheckForUpdates)
    }

    func test_init_canCheckForUpdates_isTrue_whenServiceReturnsTrue() {
        mockService.canCheckForUpdatesValue = true
        sut = UpdaterViewModel(updaterService: mockService)

        XCTAssertTrue(sut.canCheckForUpdates)
    }

    // MARK: - checkForUpdates

    func test_checkForUpdates_whenCanCheck_delegatesToService() {
        mockService.canCheckForUpdatesValue = true
        sut = UpdaterViewModel(updaterService: mockService)

        sut.checkForUpdates()

        XCTAssertTrue(mockService.checkForUpdatesCalled,
                      "checkForUpdates() must delegate to UpdaterServiceProtocol")
    }

    func test_checkForUpdates_whenCannotCheck_doesNotCallService() {
        mockService.canCheckForUpdatesValue = false
        sut = UpdaterViewModel(updaterService: mockService)

        sut.checkForUpdates()

        XCTAssertFalse(mockService.checkForUpdatesCalled,
                       "checkForUpdates() must not call service when canCheckForUpdates is false")
    }

    func test_checkForUpdates_refreshesCanCheckForUpdates_afterCall() {
        mockService.canCheckForUpdatesValue = true
        sut = UpdaterViewModel(updaterService: mockService)

        // Simulate Sparkle flipping canCheckForUpdates to false during the check
        mockService.onCheckForUpdates = { [weak self] in
            self?.mockService.canCheckForUpdatesValue = false
        }
        sut.checkForUpdates()

        XCTAssertFalse(sut.canCheckForUpdates,
                       "canCheckForUpdates must reflect updated service state after calling checkForUpdates()")
    }

    func test_checkForUpdates_calledOnce_delegatesExactlyOnce() {
        mockService.canCheckForUpdatesValue = true
        sut = UpdaterViewModel(updaterService: mockService)

        sut.checkForUpdates()
        sut.checkForUpdates()

        XCTAssertEqual(mockService.checkForUpdatesCallCount, 2,
                       "Each checkForUpdates() call that passes the guard must delegate once")
    }
}
