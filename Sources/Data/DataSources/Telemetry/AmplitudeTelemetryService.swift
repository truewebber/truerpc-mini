import AmplitudeSwift
import Foundation

/// Protocol for Amplitude-like tracking to enable unit testing.
protocol AnalyticsTrackerProtocol {
    func track(eventType: String, eventProperties: [String: Any]?)
}

extension Amplitude: AnalyticsTrackerProtocol {}

private let allowedPropertyKeys: Set<String> = [
    "source", "app_version", "os_version", "tab_name", "has_proto",
    "service_name", "method_name", "duration_ms", "error_code",
]

private let maxPropertyLength = 64

final class AmplitudeTelemetryService: TelemetryServiceProtocol {
    private let tracker: AnalyticsTrackerProtocol
    private let isEnabled: () -> Bool

    init(apiKey: String, isEnabled: @escaping () -> Bool, tracker: AnalyticsTrackerProtocol? = nil) {
        self.isEnabled = isEnabled
        self.tracker = tracker ?? Amplitude(configuration: Configuration(apiKey: apiKey))
    }

    func track(_ event: TelemetryEvent) async {
        guard isEnabled() else { return }
        let sanitized = sanitize(event)
        let properties: [String: Any]? = sanitized.properties.isEmpty
            ? nil
            : Dictionary(uniqueKeysWithValues: sanitized.properties.map { ($0.key, $0.value as Any) })
        tracker.track(eventType: sanitized.name, eventProperties: properties)
    }

    private func sanitize(_ event: TelemetryEvent) -> TelemetryEvent {
        let clean = event.properties
            .filter { allowedPropertyKeys.contains($0.key) }
            .mapValues { value in
                if value.count > maxPropertyLength {
                    return String(value.prefix(maxPropertyLength))
                }
                return value
            }
        return TelemetryEvent(name: event.name, properties: clean)
    }
}
