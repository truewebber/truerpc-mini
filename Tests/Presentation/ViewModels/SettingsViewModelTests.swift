import XCTest
@testable import TrueRPCMini

@MainActor
final class SettingsViewModelTests: XCTestCase {

    private var sut: SettingsViewModel!
    private var mockTelemetry: MockTelemetryService!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "com.truerpc.tests.SettingsViewModelTests")!
        userDefaults.removePersistentDomain(forName: "com.truerpc.tests.SettingsViewModelTests")
        mockTelemetry = MockTelemetryService()
        sut = SettingsViewModel(telemetry: mockTelemetry, userDefaults: userDefaults)
    }

    override func tearDown() {
        sut = nil
        mockTelemetry = nil
        userDefaults.removePersistentDomain(forName: "com.truerpc.tests.SettingsViewModelTests")
        userDefaults = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_init_whenAnalyticsOptOutIsTrue_isAnalyticsEnabledIsFalse() {
        userDefaults.analyticsOptOut = true
        let vm = SettingsViewModel(telemetry: mockTelemetry, userDefaults: userDefaults)

        XCTAssertFalse(vm.isAnalyticsEnabled)
    }

    func test_init_whenAnalyticsOptOutIsFalse_isAnalyticsEnabledIsTrue() {
        userDefaults.analyticsOptOut = false
        let vm = SettingsViewModel(telemetry: mockTelemetry, userDefaults: userDefaults)

        XCTAssertTrue(vm.isAnalyticsEnabled)
    }

    // MARK: - onAppear

    func test_onAppear_tracksSettingsOpenedEvent() async {
        sut.onAppear()
        await waitForEvent(named: "settings_opened")

        let names = mockTelemetry.trackedEvents.map(\.name)
        XCTAssertTrue(names.contains("settings_opened"))
    }

    func test_onAppear_doesNotTrackAnalyticsEvents() async {
        sut.onAppear()
        await waitForEvent(named: "settings_opened")

        let names = mockTelemetry.trackedEvents.map(\.name)
        XCTAssertFalse(names.contains("analytics_opt_out"))
        XCTAssertFalse(names.contains("analytics_opt_in"))
    }

    // MARK: - setAnalyticsEnabled(false)

    func test_setAnalyticsEnabled_false_tracksAnalyticsOptOutEvent() async {
        userDefaults.analyticsOptOut = false
        let vm = SettingsViewModel(telemetry: mockTelemetry, userDefaults: userDefaults)

        vm.setAnalyticsEnabled(false)
        await waitForEvent(named: "analytics_opt_out")

        let names = mockTelemetry.trackedEvents.map(\.name)
        XCTAssertTrue(names.contains("analytics_opt_out"))
    }

    func test_setAnalyticsEnabled_false_updatesUserDefaults() async {
        userDefaults.analyticsOptOut = false
        let vm = SettingsViewModel(telemetry: mockTelemetry, userDefaults: userDefaults)

        vm.setAnalyticsEnabled(false)
        await waitForEvent(named: "analytics_opt_out")
        for _ in 0..<100 { await Task.yield() }

        XCTAssertTrue(userDefaults.analyticsOptOut)
    }

    func test_setAnalyticsEnabled_false_updatesIsAnalyticsEnabled() async {
        userDefaults.analyticsOptOut = false
        let vm = SettingsViewModel(telemetry: mockTelemetry, userDefaults: userDefaults)

        vm.setAnalyticsEnabled(false)
        await waitForEvent(named: "analytics_opt_out")
        for _ in 0..<100 { await Task.yield() }

        XCTAssertFalse(vm.isAnalyticsEnabled)
    }

    /// AC: analytics_opt_out must be the last event sent BEFORE opt-out takes effect.
    /// Verifies opt_out event is tracked before UserDefaults is written.
    func test_setAnalyticsEnabled_false_optOutEventTrackedBeforeUserDefaultsIsDisabled() async {
        var eventTrackedBeforeDisable = false
        let trackingTelemetry = TrackingOrderTelemetry(userDefaults: userDefaults) {
            eventTrackedBeforeDisable = !self.userDefaults.analyticsOptOut
        }
        let vm = SettingsViewModel(telemetry: trackingTelemetry, userDefaults: userDefaults)

        vm.setAnalyticsEnabled(false)
        await waitForCustomEvent(in: trackingTelemetry, named: "analytics_opt_out")

        XCTAssertTrue(eventTrackedBeforeDisable, "analytics_opt_out must fire before UserDefaults opt-out flag is set")
    }

    // MARK: - setAnalyticsEnabled(true)

    func test_setAnalyticsEnabled_true_tracksAnalyticsOptInEvent() async {
        userDefaults.analyticsOptOut = true
        let vm = SettingsViewModel(telemetry: mockTelemetry, userDefaults: userDefaults)

        vm.setAnalyticsEnabled(true)
        await waitForEvent(named: "analytics_opt_in")

        let names = mockTelemetry.trackedEvents.map(\.name)
        XCTAssertTrue(names.contains("analytics_opt_in"))
    }

    func test_setAnalyticsEnabled_true_updatesUserDefaults() {
        userDefaults.analyticsOptOut = true
        let vm = SettingsViewModel(telemetry: mockTelemetry, userDefaults: userDefaults)

        vm.setAnalyticsEnabled(true)

        XCTAssertFalse(userDefaults.analyticsOptOut)
    }

    func test_setAnalyticsEnabled_true_updatesIsAnalyticsEnabled() {
        userDefaults.analyticsOptOut = true
        let vm = SettingsViewModel(telemetry: mockTelemetry, userDefaults: userDefaults)

        vm.setAnalyticsEnabled(true)

        XCTAssertTrue(vm.isAnalyticsEnabled)
    }

    func test_setAnalyticsEnabled_true_doesNotTrackOptOutEvent() async {
        userDefaults.analyticsOptOut = true
        let vm = SettingsViewModel(telemetry: mockTelemetry, userDefaults: userDefaults)

        vm.setAnalyticsEnabled(true)
        await waitForEvent(named: "analytics_opt_in")

        let names = mockTelemetry.trackedEvents.map(\.name)
        XCTAssertFalse(names.contains("analytics_opt_out"))
    }

    // MARK: - Helpers

    private func waitForEvent(named name: String) async {
        for _ in 0..<1000 {
            if mockTelemetry.trackedEvents.contains(where: { $0.name == name }) { return }
            await Task.yield()
        }
    }

    private func waitForCustomEvent(in telemetry: TrackingOrderTelemetry, named name: String) async {
        for _ in 0..<1000 {
            if telemetry.trackedEvents.contains(where: { $0.name == name }) { return }
            await Task.yield()
        }
    }
}

// MARK: - TrackingOrderTelemetry

/// Spy that calls a hook synchronously when the analytics_opt_out event is tracked,
/// before any async UserDefaults writes occur.
private final class TrackingOrderTelemetry: TelemetryServiceProtocol {
    private(set) var trackedEvents: [TelemetryEvent] = []
    private let userDefaults: UserDefaults
    private let onOptOutTracked: () -> Void

    init(userDefaults: UserDefaults, onOptOutTracked: @escaping () -> Void) {
        self.userDefaults = userDefaults
        self.onOptOutTracked = onOptOutTracked
    }

    func track(_ event: TelemetryEvent) async {
        trackedEvents.append(event)
        if event.name == "analytics_opt_out" {
            onOptOutTracked()
        }
    }
}
