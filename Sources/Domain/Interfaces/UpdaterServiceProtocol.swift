/// Abstraction over the app update engine.
///
/// Conforming types wrap the concrete update framework (Sparkle) so that
/// ViewModels and use cases remain framework-independent.
public protocol UpdaterServiceProtocol {
    /// Whether a user-initiated update check can be started right now.
    var canCheckForUpdates: Bool { get }

    /// Triggers a user-initiated update check; shows Sparkle's standard progress UI.
    func checkForUpdates()
}
