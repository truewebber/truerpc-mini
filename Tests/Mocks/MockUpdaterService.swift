@testable import TrueRPCMini

final class MockUpdaterService: UpdaterServiceProtocol {
    var checkForUpdatesCalled = false
    var canCheckForUpdatesValue = false

    var canCheckForUpdates: Bool { canCheckForUpdatesValue }

    func checkForUpdates() {
        checkForUpdatesCalled = true
    }
}
