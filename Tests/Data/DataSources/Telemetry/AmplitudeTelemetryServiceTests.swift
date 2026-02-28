import XCTest
@testable import TrueRPCMini

final class AmplitudeTelemetryServiceTests: XCTestCase {

    func test_track_whenEnabled_callsTrackerWithSanitizedEvent() async {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(apiKey: "test-key", isEnabled: { true }, tracker: spy)

        await sut.track(.appLaunched(appVersion: "1.0.0", osVersion: "15.0"))

        XCTAssertEqual(spy.trackedEventTypes.count, 1)
        XCTAssertEqual(spy.trackedEventTypes[0], "app_launched")
        XCTAssertEqual(spy.trackedEventProperties[0]?["app_version"] as? String, "1.0.0")
        XCTAssertEqual(spy.trackedEventProperties[0]?["os_version"] as? String, "15.0")
    }

    func test_track_whenDisabled_doesNotCallTracker() async {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(apiKey: "test-key", isEnabled: { false }, tracker: spy)

        await sut.track(.settingsOpened())

        XCTAssertTrue(spy.trackedEventTypes.isEmpty)
    }

    func test_sanitize_stripsUnknownKeys() async {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(apiKey: "test-key", isEnabled: { true }, tracker: spy)
        let event = TelemetryEvent(name: "test_event", properties: [
            "app_version": "1.0",
            "unknown_key": "should_be_dropped",
            "service_name": "MyService",
        ])

        await sut.track(event)

        let props = spy.trackedEventProperties[0] ?? [:]
        XCTAssertNotNil(props["app_version"])
        XCTAssertNotNil(props["service_name"])
        XCTAssertNil(props["unknown_key"])
    }

    func test_sanitize_truncatesServiceNameTo64Chars() async {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(apiKey: "test-key", isEnabled: { true }, tracker: spy)
        let longName = String(repeating: "a", count: 100)

        await sut.track(.requestSent(serviceName: longName, methodName: "M"))

        let props = spy.trackedEventProperties[0] ?? [:]
        let serviceName = props["service_name"] as? String ?? ""
        XCTAssertLessThanOrEqual(serviceName.count, 64)
    }

    func test_sanitize_truncatesMethodNameTo64Chars() async {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(apiKey: "test-key", isEnabled: { true }, tracker: spy)
        let longName = String(repeating: "b", count: 80)

        await sut.track(.requestSent(serviceName: "S", methodName: longName))

        let props = spy.trackedEventProperties[0] ?? [:]
        let methodName = props["method_name"] as? String ?? ""
        XCTAssertLessThanOrEqual(methodName.count, 64)
    }

    func test_isEnabledClosure_reflectsUserDefaultsAnalyticsOptOut() async {
        let userDefaults = UserDefaults(suiteName: "test.amplitude.optout.integration")!
        userDefaults.removePersistentDomain(forName: "test.amplitude.optout.integration")
        defer { userDefaults.removePersistentDomain(forName: "test.amplitude.optout.integration") }

        let spy = MockAnalyticsTracker()
        let isEnabled: () -> Bool = { !userDefaults.analyticsOptOut }
        let sut = AmplitudeTelemetryService(apiKey: "test-key", isEnabled: isEnabled, tracker: spy)

        userDefaults.analyticsOptOut = true
        await sut.track(.settingsOpened())
        XCTAssertTrue(spy.trackedEventTypes.isEmpty, "When optOut=true, no events should fire")

        spy.trackedEventTypes.removeAll()
        spy.trackedEventProperties.removeAll()
        userDefaults.analyticsOptOut = false
        await sut.track(.appLaunched(appVersion: "1.0", osVersion: "15.0"))
        XCTAssertEqual(spy.trackedEventTypes.count, 1)
        XCTAssertEqual(spy.trackedEventTypes[0], "app_launched")
    }

    func test_track_allFactoryEvents_successfullyTracked() async {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(apiKey: "test-key", isEnabled: { true }, tracker: spy)

        await sut.track(.appLaunched(appVersion: "1.0.0", osVersion: "15.0"))
        await sut.track(.appBackgrounded())
        await sut.track(.appForegrounded())
        await sut.track(.protoAdded(source: "file"))
        await sut.track(.protoRemoved())
        await sut.track(.requestSent(serviceName: "Svc", methodName: "Mth"))
        await sut.track(.requestSucceeded(serviceName: "Svc", methodName: "Mth", durationMs: 100))
        await sut.track(.requestFailed(serviceName: "Svc", methodName: "Mth", errorCode: "UNAVAILABLE"))
        await sut.track(.tabSwitched(tabName: "protos"))
        await sut.track(.settingsOpened())

        let expectedNames = [
            "app_launched", "app_backgrounded", "app_foregrounded",
            "proto_added", "proto_removed", "request_sent", "request_succeeded",
            "request_failed", "tab_switched", "settings_opened",
        ]
        XCTAssertEqual(spy.trackedEventTypes, expectedNames)
    }
}

private final class MockAnalyticsTracker: AnalyticsTrackerProtocol {
    var trackedEventTypes: [String] = []
    var trackedEventProperties: [[String: Any]?] = []

    func track(eventType: String, eventProperties: [String: Any]?) {
        trackedEventTypes.append(eventType)
        trackedEventProperties.append(eventProperties)
    }
}
