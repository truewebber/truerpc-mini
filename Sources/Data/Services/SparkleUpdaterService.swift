import Sparkle

/// Internal protocol that abstracts `SPUStandardUpdaterController` for unit-test isolation.
/// `SPUStandardUpdaterController` is made to conform via extension below.
@MainActor
protocol SparkleUpdating: AnyObject {
    var canCheckForUpdates: Bool { get }
    func checkForUpdates()
}

@MainActor
extension SPUStandardUpdaterController: SparkleUpdating {
    func checkForUpdates() {
        checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }
}

@MainActor
extension SPUUpdater: SparkleUpdating {}

/// Concrete updater service that delegates to Sparkle 2.
///
/// Inject `SparkleUpdating` directly in unit tests (using `MockSparkleUpdating`);
/// the production composition root passes a live `SPUStandardUpdaterController`.
@MainActor
final class SparkleUpdaterService: UpdaterServiceProtocol {
    // MARK: - Private

    private let updater: any SparkleUpdating

    // MARK: - Init

    init(updater: any SparkleUpdating) {
        self.updater = updater
    }

    // MARK: - UpdaterServiceProtocol

    var canCheckForUpdates: Bool {
        updater.canCheckForUpdates
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
