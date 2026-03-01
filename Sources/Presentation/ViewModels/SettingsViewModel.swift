import Foundation

/// ViewModel for the Settings screen.
///
/// Tracks `settings_opened` when the screen appears.
@MainActor
public final class SettingsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let telemetry: TelemetryServiceProtocol

    // MARK: - Initialization

    public init(telemetry: TelemetryServiceProtocol) {
        self.telemetry = telemetry
    }

    // MARK: - Lifecycle

    /// Call when the Settings screen appears.
    /// Tracks the `settings_opened` event.
    public func onAppear() {
        Task { await telemetry.track(.settingsOpened()) }
    }
}
