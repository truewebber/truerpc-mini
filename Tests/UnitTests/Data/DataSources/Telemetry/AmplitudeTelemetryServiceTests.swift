import AmplitudeSwift
import os.lock
import XCTest
@testable import TrueRPCMini

@MainActor
final class AmplitudeTelemetryServiceTests: XCTestCase {
    // MARK: - track

    func test_track_whenEnabled_callsTrackerWithSanitizedEvent() {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(
            apiKey: "test-key",
            isEnabled: { true },
            responseHandler: MockTrackerResponseHandler(),
            tracker: spy)

        sut.track(.appLaunched(appVersion: "1.0.0", osVersion: "15.0"))

        XCTAssertEqual(spy.trackedEventTypes.count, 1)
        XCTAssertEqual(spy.trackedEventTypes[0], "app_launched")
        XCTAssertEqual(spy.trackedEventProperties[0]?["app_version"] as? String, "1.0.0")
        XCTAssertEqual(spy.trackedEventProperties[0]?["os_version"] as? String, "15.0")
    }

    // MARK: - sanitize

    func test_sanitize_stripsUnknownKeys() {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(
            apiKey: "test-key",
            isEnabled: { true },
            responseHandler: MockTrackerResponseHandler(),
            tracker: spy)
        let event = TelemetryEvent(name: "test_event", properties: [
            "app_version": "1.0",
            "unknown_key": "should_be_dropped",
            "service_name": "MyService",
        ])

        sut.track(event)

        let props = spy.trackedEventProperties[0] ?? [:]
        XCTAssertNotNil(props["app_version"])
        XCTAssertNotNil(props["service_name"])
        XCTAssertNil(props["unknown_key"])
    }

    func test_sanitize_truncatesServiceNameTo64Chars() {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(
            apiKey: "test-key",
            isEnabled: { true },
            responseHandler: MockTrackerResponseHandler(),
            tracker: spy)
        let longName = String(repeating: "a", count: 100)

        sut.track(.requestSent(serviceName: longName, methodName: "M"))

        let props = spy.trackedEventProperties[0] ?? [:]
        let serviceName = props["service_name"] as? String ?? ""
        XCTAssertLessThanOrEqual(serviceName.count, 64)
    }

    func test_sanitize_truncatesMethodNameTo64Chars() {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(
            apiKey: "test-key",
            isEnabled: { true },
            responseHandler: MockTrackerResponseHandler(),
            tracker: spy)
        let longName = String(repeating: "b", count: 80)

        sut.track(.requestSent(serviceName: "S", methodName: longName))

        let props = spy.trackedEventProperties[0] ?? [:]
        let methodName = props["method_name"] as? String ?? ""
        XCTAssertLessThanOrEqual(methodName.count, 64)
    }

    // MARK: - isEnabled closure

    func test_isEnabledClosure_reflectsUserDefaultsAnalyticsIsEnabled() throws {
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: "test.amplitude.analytics.integration"))
        userDefaults.removePersistentDomain(forName: "test.amplitude.analytics.integration")
        defer { userDefaults.removePersistentDomain(forName: "test.amplitude.analytics.integration") }

        let spy = MockAnalyticsTracker()
        let isEnabled: () -> Bool = { userDefaults.analyticsIsEnabled }
        let sut = AmplitudeTelemetryService(
            apiKey: "test-key",
            isEnabled: isEnabled,
            responseHandler: MockTrackerResponseHandler(),
            tracker: spy)

        userDefaults.analyticsIsEnabled = false
        sut.track(.settingsOpened())
        XCTAssertTrue(spy.trackedEventTypes.isEmpty, "When analyticsIsEnabled=false, no events should fire")

        spy.trackedEventTypes.removeAll()
        spy.trackedEventProperties.removeAll()
        userDefaults.analyticsIsEnabled = true
        sut.track(.appLaunched(appVersion: "1.0", osVersion: "15.0"))
        XCTAssertEqual(spy.trackedEventTypes.count, 1)
        XCTAssertEqual(spy.trackedEventTypes[0], "app_launched")
    }

    // MARK: - sessionTimeoutMs

    func test_sessionTimeoutMs_is30Minutes() {
        XCTAssertEqual(
            AmplitudeTelemetryService.sessionTimeoutMs,
            30 * 60 * 1000,
            "Session timeout must be 30 minutes so idle desktop sessions don't inflate duration")
    }

    // MARK: - all factory events

    func test_track_allFactoryEvents_successfullyTracked() {
        let spy = MockAnalyticsTracker()
        let sut = AmplitudeTelemetryService(
            apiKey: "test-key",
            isEnabled: { true },
            responseHandler: MockTrackerResponseHandler(),
            tracker: spy)

        sut.track(.appLaunched(appVersion: "1.0.0", osVersion: "15.0"))
        sut.track(.appBackgrounded())
        sut.track(.appForegrounded())
        sut.track(.protoAdded(source: "file"))
        sut.track(.protoRemoved())
        sut.track(.requestSent(serviceName: "Svc", methodName: "Mth"))
        sut.track(.requestSucceeded(serviceName: "Svc", methodName: "Mth", durationMs: 100))
        sut.track(.requestFailed(serviceName: "Svc", methodName: "Mth", errorCode: "UNAVAILABLE"))
        sut.track(.tabSwitched(tabName: "protos"))
        sut.track(.settingsOpened())

        let expectedNames = [
            "app_launched", "app_backgrounded", "app_foregrounded",
            "proto_added", "proto_removed", "request_sent", "request_succeeded",
            "request_failed", "tab_switched", "settings_opened",
        ]
        XCTAssertEqual(spy.trackedEventTypes, expectedNames)
    }

    // MARK: - makeCallback: argument forwarding (positive)

    func test_makeCallback_forwardsEventTypeToHandler() {
        let spy = SpyTrackerResponseHandler()
        let callback = AmplitudeTelemetryService.makeCallback(responseHandler: spy)

        callback(BaseEvent(eventType: "my_event"), 200, "OK")

        XCTAssertEqual(spy.receivedEventType, "my_event")
    }

    func test_makeCallback_forwardsCodeToHandler() {
        let spy = SpyTrackerResponseHandler()
        let callback = AmplitudeTelemetryService.makeCallback(responseHandler: spy)

        callback(BaseEvent(eventType: "e"), 429, "Too Many Requests")

        XCTAssertEqual(spy.receivedCode, 429)
    }

    func test_makeCallback_forwardsMessageToHandler() {
        let spy = SpyTrackerResponseHandler()
        let callback = AmplitudeTelemetryService.makeCallback(responseHandler: spy)

        callback(BaseEvent(eventType: "e"), 500, "Internal Server Error")

        XCTAssertEqual(spy.receivedMessage, "Internal Server Error")
    }

    // MARK: - makeCallback: thread safety (regression — was crashing before the fix)

    /// Simulates the exact scenario from the crash report:
    /// Amplitude calls the callback on `com.amplitude.analytics` (a background queue).
    /// Before the fix the closure inherited `@MainActor` isolation and Swift 6 runtime
    /// called `_dispatch_assert_queue_fail` → SIGTRAP.
    func test_makeCallback_calledFromAmplitudeQueue_invokesHandlerWithoutCrashing() async {
        let spy = SpyTrackerResponseHandler()
        let callback = AmplitudeTelemetryService.makeCallback(responseHandler: spy)
        let amplitudeQueue = DispatchQueue(label: "com.amplitude.analytics")

        await withCheckedContinuation { continuation in
            amplitudeQueue.async {
                callback(BaseEvent(eventType: "queued_event"), 200, "OK")
                continuation.resume()
            }
        }

        XCTAssertEqual(spy.receivedEventType, "queued_event")
        XCTAssertEqual(spy.receivedCode, 200)
    }

    /// Verifies the callback is safe to invoke from a Swift Concurrency detached task
    /// (which runs on the cooperative thread pool, never on the main actor).
    func test_makeCallback_calledFromDetachedTask_invokesHandlerWithoutCrashing() async {
        let spy = SpyTrackerResponseHandler()
        let callback = AmplitudeTelemetryService.makeCallback(responseHandler: spy)

        await Task.detached {
            callback(BaseEvent(eventType: "detached_event"), 400, "Bad Request")
        }.value

        XCTAssertEqual(spy.receivedEventType, "detached_event")
        XCTAssertEqual(spy.receivedCode, 400)
        XCTAssertEqual(spy.receivedMessage, "Bad Request")
    }

    /// Non-200 codes must still be forwarded so the handler can log failures.
    func test_makeCallback_withNon200Code_stillCallsHandler() async {
        let spy = SpyTrackerResponseHandler()
        let callback = AmplitudeTelemetryService.makeCallback(responseHandler: spy)
        let amplitudeQueue = DispatchQueue(label: "com.amplitude.analytics")

        await withCheckedContinuation { continuation in
            amplitudeQueue.async {
                callback(BaseEvent(eventType: "failed_event"), 503, "Service Unavailable")
                continuation.resume()
            }
        }

        XCTAssertEqual(spy.receivedCode, 503)
        XCTAssertEqual(spy.receivedMessage, "Service Unavailable")
    }
}

// MARK: - Mocks

private final class MockAnalyticsTracker: AnalyticsTrackerProtocol {
    var trackedEventTypes: [String] = []
    var trackedEventProperties: [[String: Any]?] = []

    func track(eventType: String, eventProperties: [String: Any]?) {
        trackedEventTypes.append(eventType)
        trackedEventProperties.append(eventProperties)
    }
}

private final class MockTrackerResponseHandler: TrackerResponseHandlerProtocol {
    func handleResponse(eventType _: String, code _: Int, message _: String) {}
}

/// Thread-safe spy for `TrackerResponseHandlerProtocol`.
/// Guards mutable state with `OSAllocatedUnfairLock` so it can be safely captured
/// in closures invoked from background threads (per Swift 6 concurrency rules).
private final class SpyTrackerResponseHandler: TrackerResponseHandlerProtocol, Sendable {
    private struct State: Sendable {
        var eventType: String?
        var code: Int?
        var message: String?
    }

    private let storage = OSAllocatedUnfairLock(initialState: State())

    var receivedEventType: String? { storage.withLock { $0.eventType } }
    var receivedCode: Int? { storage.withLock { $0.code } }
    var receivedMessage: String? { storage.withLock { $0.message } }

    func handleResponse(eventType: String, code: Int, message: String) {
        storage.withLock {
            $0.eventType = eventType
            $0.code = code
            $0.message = message
        }
    }
}
