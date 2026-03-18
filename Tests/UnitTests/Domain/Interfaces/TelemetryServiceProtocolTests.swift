import XCTest
@testable import TrueRPCMini

@MainActor
final class TelemetryServiceProtocolTests: XCTestCase {
    func test_mockTelemetryService_capturesTrackedEvents() {
        let mock = MockTelemetryService()
        let event = TelemetryEvent.appLaunched(appVersion: "1.0.0", osVersion: "15.0")

        mock.track(event)

        XCTAssertEqual(mock.trackedEvents.count, 1)
        XCTAssertEqual(mock.trackedEvents[0].name, event.name)
        XCTAssertEqual(mock.trackedEvents[0].properties, event.properties)
    }

    func test_mockTelemetryService_capturesMultipleEvents() {
        let mock = MockTelemetryService()
        let event1 = TelemetryEvent.settingsOpened()
        let event2 = TelemetryEvent.tabSwitched(tabName: "protos")

        mock.track(event1)
        mock.track(event2)

        XCTAssertEqual(mock.trackedEvents.count, 2)
        XCTAssertEqual(mock.trackedEvents[0].name, "settings_opened")
        XCTAssertEqual(mock.trackedEvents[1].name, "tab_switched")
    }
}
