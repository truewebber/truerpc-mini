import XCTest
@testable import TrueRPCMini

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var sut: SettingsViewModel!
    private var mockTelemetry: MockTelemetryService!

    override func setUp() async throws {
        try await super.setUp()
        mockTelemetry = MockTelemetryService()
        sut = SettingsViewModel(telemetry: mockTelemetry)
    }

    override func tearDown() async throws {
        sut = nil
        mockTelemetry = nil
        try await super.tearDown()
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

    // MARK: - Helpers

    private func waitForEvent(named name: String) async {
        for _ in 0 ..< 1000 {
            if mockTelemetry.trackedEvents.contains(where: { $0.name == name }) { return }
            await Task.yield()
        }
    }
}
