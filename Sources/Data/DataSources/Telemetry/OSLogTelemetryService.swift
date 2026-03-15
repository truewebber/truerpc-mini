#if DEBUG
    import Foundation
    import os

    /// Debug-only TelemetryServiceProtocol implementation that logs events to Console.app.
    /// Not compiled in Release — use AmplitudeTelemetryService instead.
    @MainActor
    struct OSLogTelemetryService: TelemetryServiceProtocol {
        private let logger: os.Logger
        private let testSink: ((String) -> Void)?

        init(
            subsystem: String = Bundle.main.bundleIdentifier ?? "com.truewebber",
            category: String = "telemetry",
            testSink: ((String) -> Void)? = nil)
        {
            self.logger = os.Logger(subsystem: subsystem, category: category)
            self.testSink = testSink
        }

        func track(_ event: TelemetryEvent) {
            let props = event.properties
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: " ")
            let message = "[event] \(event.name) \(props)"
            if let testSink {
                testSink(message)
            } else {
                logger.debug("\(message, privacy: .public)")
            }
        }
    }
#endif
