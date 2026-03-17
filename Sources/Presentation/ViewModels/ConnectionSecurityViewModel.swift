import Foundation

/// Manages all TLS-related state for a single editor tab.
/// Owned by `EditorTabViewModel` — one instance per tab.
@MainActor
public final class ConnectionSecurityViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The ad-hoc TLS configuration, editable only in custom URL mode.
    /// Persisted externally via `EditorTabState.adHocTLSConfiguration`.
    @Published public var adHocConfig: TLSConfiguration = .defaults

    /// Controls visibility of the TLS settings popover.
    @Published public var isPopoverPresented: Bool = false

    // MARK: - Private State

    private var activeEnvironment: ServerEnvironment?

    // MARK: - Computed Properties

    /// True when a named `ServerEnvironment` is active; TLS is read-only in this mode.
    public var isEnvironmentMode: Bool {
        activeEnvironment != nil
    }

    /// The effective TLS configuration: environment's config in environment mode, else `adHocConfig`.
    public var effectiveTLSConfiguration: TLSConfiguration {
        activeEnvironment?.tlsConfiguration ?? adHocConfig
    }

    /// Lock indicator state derived from the effective TLS configuration.
    public var lockState: LockIndicatorState {
        effectiveTLSConfiguration.lockIndicatorState
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Updates the active environment and restores a persisted ad-hoc config.
    /// Called by `EditorTabViewModel` on init and on every environment change.
    public func update(activeEnvironment: ServerEnvironment?, restoredAdHocConfig: TLSConfiguration?) {
        self.activeEnvironment = activeEnvironment
        if let restoredAdHocConfig {
            adHocConfig = restoredAdHocConfig
        }
    }
}
