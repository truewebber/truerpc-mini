import Foundation
@testable import TrueRPCMini

/// Spy implementation of TelemetryServiceProtocol for testing
public final class MockTelemetryService: TelemetryServiceProtocol {
    public private(set) var trackedEvents: [TelemetryEvent] = []

    public init() {}

    public func track(_ event: TelemetryEvent) async {
        trackedEvents.append(event)
    }
}
