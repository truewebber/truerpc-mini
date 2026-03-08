/// Logs non-200 tracker responses as warnings so delivery failures surface in Sentry.
final class LoggingTrackerResponseHandler: TrackerResponseHandlerProtocol {
    private let logger: any AppLogger

    init(logger: any AppLogger) {
        self.logger = logger
    }

    func handleResponse(eventType: String, code: Int, message: String) {
        guard code != 200 else { return }

        logger.warning(
            "Amplitude event delivery failed",
            metadata: ["event": eventType, "code": String(code), "message": message])
    }
}
