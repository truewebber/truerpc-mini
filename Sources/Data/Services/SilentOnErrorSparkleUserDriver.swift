import Sparkle

/// A `SPUUserDriver` that delegates all update UI to `SPUStandardUserDriver`
/// except fatal updater errors, which are logged silently without showing a dialog.
@MainActor
final class SilentOnErrorSparkleUserDriver: NSObject, SPUUserDriver {
    private let base: SPUStandardUserDriver
    private let logger: any AppLogger

    init(hostBundle: Bundle, delegate: (any SPUStandardUserDriverDelegate)?, logger: any AppLogger) {
        self.base = SPUStandardUserDriver(hostBundle: hostBundle, delegate: delegate)
        self.logger = logger
    }

    // MARK: - Fatal errors: log only, no dialog

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        logger.error("Sparkle: fatal error", metadata: ["error": error.localizedDescription])
        acknowledgement()
    }

    // MARK: - Forward everything else to SPUStandardUserDriver

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        base.show(request, reply: reply)
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        base.showUserInitiatedUpdateCheck(cancellation: cancellation)
    }

    func showUpdateFound(
        with appcastItem: SUAppcastItem,
        state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void)
    {
        base.showUpdateFound(with: appcastItem, state: state, reply: reply)
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        base.showUpdateReleaseNotes(with: downloadData)
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
        base.showUpdateReleaseNotesFailedToDownloadWithError(error)
    }

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        base.showUpdateNotFoundWithError(error, acknowledgement: acknowledgement)
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        base.showDownloadInitiated(cancellation: cancellation)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        base.showDownloadDidReceiveExpectedContentLength(expectedContentLength)
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        base.showDownloadDidReceiveData(ofLength: length)
    }

    func showDownloadDidStartExtractingUpdate() {
        base.showDownloadDidStartExtractingUpdate()
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        base.showExtractionReceivedProgress(progress)
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        base.showReady(toInstallAndRelaunch: reply)
    }

    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void)
    {
        base.showInstallingUpdate(
            withApplicationTerminated: applicationTerminated,
            retryTerminatingApplication: retryTerminatingApplication)
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        base.showUpdateInstalledAndRelaunched(relaunched, acknowledgement: acknowledgement)
    }

    func dismissUpdateInstallation() {
        base.dismissUpdateInstallation()
    }

    func showUpdateInFocus() {
        base.showUpdateInFocus()
    }
}
