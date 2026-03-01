/// Handles the per-event response callback fired by the analytics tracker after delivery.
protocol TrackerResponseHandlerProtocol {
    func handleResponse(eventType: String, code: Int, message: String)
}
