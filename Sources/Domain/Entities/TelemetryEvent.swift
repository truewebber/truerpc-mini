/// SDK-agnostic representation of an analytics event.
///
/// All event names and property keys are string constants — no SDK imports required.
/// Factory methods enforce the event catalog and prevent typos in event names.
public struct TelemetryEvent {
    public let name: String
    public let properties: [String: String]

    public init(name: String, properties: [String: String]) {
        self.name = name
        self.properties = properties
    }
}

// MARK: - Event catalog

public extension TelemetryEvent {

    static func appLaunched(appVersion: String, osVersion: String) -> TelemetryEvent {
        TelemetryEvent(
            name: "app_launched",
            properties: [
                "app_version": appVersion,
                "os_version": osVersion,
            ]
        )
    }

    static func appBackgrounded() -> TelemetryEvent {
        TelemetryEvent(name: "app_backgrounded", properties: [:])
    }

    static func appForegrounded() -> TelemetryEvent {
        TelemetryEvent(name: "app_foregrounded", properties: [:])
    }

    static func protoAdded(source: String) -> TelemetryEvent {
        TelemetryEvent(name: "proto_added", properties: ["source": source])
    }

    static func protoRemoved() -> TelemetryEvent {
        TelemetryEvent(name: "proto_removed", properties: [:])
    }

    static func requestSent(serviceName: String, methodName: String) -> TelemetryEvent {
        TelemetryEvent(
            name: "request_sent",
            properties: [
                "service_name": serviceName,
                "method_name": methodName,
            ]
        )
    }

    static func requestSucceeded(serviceName: String, methodName: String, durationMs: Int) -> TelemetryEvent {
        TelemetryEvent(
            name: "request_succeeded",
            properties: [
                "service_name": serviceName,
                "method_name": methodName,
                "duration_ms": String(durationMs),
            ]
        )
    }

    static func requestFailed(serviceName: String, methodName: String, errorCode: String) -> TelemetryEvent {
        TelemetryEvent(
            name: "request_failed",
            properties: [
                "service_name": serviceName,
                "method_name": methodName,
                "error_code": errorCode,
            ]
        )
    }

    static func tabSwitched(tabName: String) -> TelemetryEvent {
        TelemetryEvent(name: "tab_switched", properties: ["tab_name": tabName])
    }

    static func settingsOpened() -> TelemetryEvent {
        TelemetryEvent(name: "settings_opened", properties: [:])
    }
}
