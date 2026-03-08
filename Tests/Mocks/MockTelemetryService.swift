import Foundation
@testable import TrueRPCMini

/// Spy implementation of TelemetryServiceProtocol for testing
public final class MockTelemetryService: TelemetryServiceProtocol {
    public private(set) var trackedEvents: [TelemetryEvent] = []

    public init() {}

    public func track(_ event: TelemetryEvent) {
        trackedEvents.append(event)
    }

    public func reset() {
        trackedEvents = []
    }
}
