@testable import TrueRPCMini

final class MockUpdaterService: UpdaterServiceProtocol {
    var checkForUpdatesCallCount = 0
    var checkForUpdatesCalled: Bool {
        checkForUpdatesCallCount > 0
    }

    var canCheckForUpdatesValue = false

    /// Optional side-effect invoked inside `checkForUpdates()`.
    /// Use to simulate Sparkle flipping `canCheckForUpdates` during a check.
    var onCheckForUpdates: (() -> Void)?

    var canCheckForUpdates: Bool {
        canCheckForUpdatesValue
    }

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
        onCheckForUpdates?()
    }
}
