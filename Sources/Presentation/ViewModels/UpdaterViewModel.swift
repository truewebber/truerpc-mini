import Foundation

/// ViewModel for the "Check for Updates..." menu action.
///
/// Delegates to `UpdaterServiceProtocol` (Sparkle under the hood).
/// Sparkle provides native dialogs for "Update available" (Update / Cancel)
/// and "You're up to date" — no custom UI is required here.
///
/// Cancel in Sparkle's manual-check dialog does NOT record a skip state;
/// this differs from the auto-prompt where "Skip" persists the skipped version.
@MainActor
public final class UpdaterViewModel: ObservableObject {
    // MARK: - Published State

    /// Mirrors `UpdaterServiceProtocol.canCheckForUpdates`.
    /// Used to disable the menu item while a check is already in progress.
    @Published public private(set) var canCheckForUpdates: Bool

    // MARK: - Dependencies

    private let updaterService: any UpdaterServiceProtocol

    // MARK: - Init

    public init(updaterService: any UpdaterServiceProtocol) {
        self.updaterService = updaterService
        self.canCheckForUpdates = updaterService.canCheckForUpdates
    }

    // MARK: - Actions

    /// Triggers a user-initiated update check.
    ///
    /// Does nothing when `canCheckForUpdates` is false (check already in progress).
    /// After the call, `canCheckForUpdates` is refreshed from the service.
    public func checkForUpdates() {
        guard updaterService.canCheckForUpdates else { return }
        updaterService.checkForUpdates()
        canCheckForUpdates = updaterService.canCheckForUpdates
    }
}
