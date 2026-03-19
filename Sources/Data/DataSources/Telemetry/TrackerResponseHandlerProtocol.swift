/// Handles the per-event response callback fired by the analytics tracker after delivery.
///
/// `Sendable` is required because implementations are captured by closures that Amplitude
/// invokes on its own background queue (`com.amplitude.analytics`), not on the main actor.
protocol TrackerResponseHandlerProtocol: Sendable {
    func handleResponse(eventType: String, code: Int, message: String)
}
