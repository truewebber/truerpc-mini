import XCTest
@testable import TrueRPCMini

final class TelemetryEventTests: XCTestCase {

    // MARK: - Struct shape

    func test_init_storesNameAndProperties() {
        let event = TelemetryEvent(name: "some_event", properties: ["key": "value"])

        XCTAssertEqual(event.name, "some_event")
        XCTAssertEqual(event.properties, ["key": "value"])
    }

    func test_init_allowsEmptyProperties() {
        let event = TelemetryEvent(name: "empty", properties: [:])

        XCTAssertTrue(event.properties.isEmpty)
    }

    // MARK: - app_launched

    func test_appLaunched_setsCorrectName() {
        let event = TelemetryEvent.appLaunched(appVersion: "1.0.0", osVersion: "15.0")

        XCTAssertEqual(event.name, "app_launched")
    }

    func test_appLaunched_setsAppVersion() {
        let event = TelemetryEvent.appLaunched(appVersion: "2.3.4", osVersion: "15.0")

        XCTAssertEqual(event.properties["app_version"], "2.3.4")
    }

    func test_appLaunched_setsOsVersion() {
        let event = TelemetryEvent.appLaunched(appVersion: "1.0.0", osVersion: "14.5")

        XCTAssertEqual(event.properties["os_version"], "14.5")
    }

    func test_appLaunched_hasExactlyTwoProperties() {
        let event = TelemetryEvent.appLaunched(appVersion: "1.0.0", osVersion: "15.0")

        XCTAssertEqual(event.properties.count, 2)
    }

    // MARK: - app_backgrounded

    func test_appBackgrounded_setsCorrectName() {
        let event = TelemetryEvent.appBackgrounded()

        XCTAssertEqual(event.name, "app_backgrounded")
    }

    func test_appBackgrounded_hasNoProperties() {
        let event = TelemetryEvent.appBackgrounded()

        XCTAssertTrue(event.properties.isEmpty)
    }

    // MARK: - app_foregrounded

    func test_appForegrounded_setsCorrectName() {
        let event = TelemetryEvent.appForegrounded()

        XCTAssertEqual(event.name, "app_foregrounded")
    }

    func test_appForegrounded_hasNoProperties() {
        let event = TelemetryEvent.appForegrounded()

        XCTAssertTrue(event.properties.isEmpty)
    }

    // MARK: - proto_added

    func test_protoAdded_setsCorrectName() {
        let event = TelemetryEvent.protoAdded(source: "file")

        XCTAssertEqual(event.name, "proto_added")
    }

    func test_protoAdded_setsSourceFile() {
        let event = TelemetryEvent.protoAdded(source: "file")

        XCTAssertEqual(event.properties["source"], "file")
    }

    func test_protoAdded_setsSourceUrl() {
        let event = TelemetryEvent.protoAdded(source: "url")

        XCTAssertEqual(event.properties["source"], "url")
    }

    func test_protoAdded_hasExactlyOneProperty() {
        let event = TelemetryEvent.protoAdded(source: "file")

        XCTAssertEqual(event.properties.count, 1)
    }

    // MARK: - proto_removed

    func test_protoRemoved_setsCorrectName() {
        let event = TelemetryEvent.protoRemoved()

        XCTAssertEqual(event.name, "proto_removed")
    }

    func test_protoRemoved_hasNoProperties() {
        let event = TelemetryEvent.protoRemoved()

        XCTAssertTrue(event.properties.isEmpty)
    }

    // MARK: - request_sent

    func test_requestSent_setsCorrectName() {
        let event = TelemetryEvent.requestSent(serviceName: "MyService", methodName: "GetUser")

        XCTAssertEqual(event.name, "request_sent")
    }

    func test_requestSent_setsServiceName() {
        let event = TelemetryEvent.requestSent(serviceName: "MyService", methodName: "GetUser")

        XCTAssertEqual(event.properties["service_name"], "MyService")
    }

    func test_requestSent_setsMethodName() {
        let event = TelemetryEvent.requestSent(serviceName: "MyService", methodName: "GetUser")

        XCTAssertEqual(event.properties["method_name"], "GetUser")
    }

    func test_requestSent_hasExactlyTwoProperties() {
        let event = TelemetryEvent.requestSent(serviceName: "S", methodName: "M")

        XCTAssertEqual(event.properties.count, 2)
    }

    // MARK: - request_succeeded

    func test_requestSucceeded_setsCorrectName() {
        let event = TelemetryEvent.requestSucceeded(serviceName: "S", methodName: "M", durationMs: 120)

        XCTAssertEqual(event.name, "request_succeeded")
    }

    func test_requestSucceeded_setsServiceName() {
        let event = TelemetryEvent.requestSucceeded(serviceName: "MyService", methodName: "M", durationMs: 50)

        XCTAssertEqual(event.properties["service_name"], "MyService")
    }

    func test_requestSucceeded_setsMethodName() {
        let event = TelemetryEvent.requestSucceeded(serviceName: "S", methodName: "GetUser", durationMs: 50)

        XCTAssertEqual(event.properties["method_name"], "GetUser")
    }

    func test_requestSucceeded_setsDurationMs() {
        let event = TelemetryEvent.requestSucceeded(serviceName: "S", methodName: "M", durationMs: 250)

        XCTAssertEqual(event.properties["duration_ms"], "250")
    }

    func test_requestSucceeded_hasExactlyThreeProperties() {
        let event = TelemetryEvent.requestSucceeded(serviceName: "S", methodName: "M", durationMs: 10)

        XCTAssertEqual(event.properties.count, 3)
    }

    // MARK: - request_failed

    func test_requestFailed_setsCorrectName() {
        let event = TelemetryEvent.requestFailed(serviceName: "S", methodName: "M", errorCode: "UNAVAILABLE")

        XCTAssertEqual(event.name, "request_failed")
    }

    func test_requestFailed_setsServiceName() {
        let event = TelemetryEvent.requestFailed(serviceName: "MyService", methodName: "M", errorCode: "UNAVAILABLE")

        XCTAssertEqual(event.properties["service_name"], "MyService")
    }

    func test_requestFailed_setsMethodName() {
        let event = TelemetryEvent.requestFailed(serviceName: "S", methodName: "GetUser", errorCode: "UNAVAILABLE")

        XCTAssertEqual(event.properties["method_name"], "GetUser")
    }

    func test_requestFailed_setsErrorCode() {
        let event = TelemetryEvent.requestFailed(serviceName: "S", methodName: "M", errorCode: "DEADLINE_EXCEEDED")

        XCTAssertEqual(event.properties["error_code"], "DEADLINE_EXCEEDED")
    }

    func test_requestFailed_hasExactlyThreeProperties() {
        let event = TelemetryEvent.requestFailed(serviceName: "S", methodName: "M", errorCode: "E")

        XCTAssertEqual(event.properties.count, 3)
    }

    // MARK: - tab_switched

    func test_tabSwitched_setsCorrectName() {
        let event = TelemetryEvent.tabSwitched(tabName: "protos")

        XCTAssertEqual(event.name, "tab_switched")
    }

    func test_tabSwitched_setsTabName() {
        let event = TelemetryEvent.tabSwitched(tabName: "request")

        XCTAssertEqual(event.properties["tab_name"], "request")
    }

    func test_tabSwitched_hasExactlyOneProperty() {
        let event = TelemetryEvent.tabSwitched(tabName: "settings")

        XCTAssertEqual(event.properties.count, 1)
    }

    // MARK: - settings_opened

    func test_settingsOpened_setsCorrectName() {
        let event = TelemetryEvent.settingsOpened()

        XCTAssertEqual(event.name, "settings_opened")
    }

    func test_settingsOpened_hasNoProperties() {
        let event = TelemetryEvent.settingsOpened()

        XCTAssertTrue(event.properties.isEmpty)
    }
}
