import Sparkle

/// `SPUUpdaterDelegate` that forwards Sparkle lifecycle events to the app logger.
///
/// The `SPUUpdaterDelegate` protocol methods receive a concrete `SPUUpdater` that cannot be
/// mocked in unit tests. The actual log calls are therefore extracted into internal helpers
/// (`logUpdateFound`, `logNoUpdateFound`, `logUpdateError`) so tests can exercise the logging
/// logic directly without requiring a live Sparkle instance.
final class SparkleUpdaterDelegate: NSObject {
    private let logger: any AppLogger

    init(logger: any AppLogger) {
        self.logger = logger
    }

    // MARK: - Testable logging helpers

    func logUpdateFound(version: String, build: String) {
        logger.info("Sparkle: update available \(version)",
                    metadata: ["version": version, "build": build])
    }

    func logNoUpdateFound() {
        logger.info("Sparkle: app is up to date")
    }

    func logUpdateError(_ error: Error) {
        logger.error("Sparkle: update check failed",
                     metadata: ["error": error.localizedDescription])
    }
}

// MARK: - SPUUpdaterDelegate

extension SparkleUpdaterDelegate: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        logUpdateFound(version: item.displayVersionString, build: item.versionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        logNoUpdateFound()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        logUpdateError(error)
    }
}
