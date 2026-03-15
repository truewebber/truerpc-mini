/// Analytics interface used by ViewModels and UseCases.
///
/// Implementations (e.g. Amplitude) live in the Data layer.
/// Callers use fire-and-forget: `Task { await telemetry.track(...) }`
@MainActor
public protocol TelemetryServiceProtocol: Sendable {
    func track(_ event: TelemetryEvent) async
}
