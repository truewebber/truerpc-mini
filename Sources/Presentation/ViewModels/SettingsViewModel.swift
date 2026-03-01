import Foundation

/// ViewModel for the Settings screen.
///
/// Manages the analytics opt-in/out toggle and fires the appropriate
/// telemetry events. The `analytics_opt_out` event is always the last
/// event tracked before opt-out takes effect, satisfying the ordering
/// requirement from the event spec.
@MainActor
public final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isAnalyticsEnabled: Bool

    // MARK: - Dependencies

    private let telemetry: TelemetryServiceProtocol
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    public init(
        telemetry: TelemetryServiceProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.telemetry = telemetry
        self.userDefaults = userDefaults
        self.isAnalyticsEnabled = !userDefaults.analyticsOptOut
    }

    // MARK: - Lifecycle

    /// Call when the Settings screen appears.
    /// Tracks the `settings_opened` event.
    public func onAppear() {
        Task { await telemetry.track(.settingsOpened()) }
    }

    // MARK: - Analytics Toggle

    /// Enables or disables analytics.
    ///
    /// When disabling: fires `analytics_opt_out` first, then writes to UserDefaults.
    /// When enabling: writes to UserDefaults first, then fires `analytics_opt_in`.
    public func setAnalyticsEnabled(_ enabled: Bool) {
        if enabled {
            userDefaults.analyticsOptOut = false
            isAnalyticsEnabled = true
            Task { await telemetry.track(.analyticsOptIn()) }
        } else {
            Task {
                await telemetry.track(.analyticsOptOut())
                userDefaults.analyticsOptOut = true
                await MainActor.run { isAnalyticsEnabled = false }
            }
        }
    }
}
