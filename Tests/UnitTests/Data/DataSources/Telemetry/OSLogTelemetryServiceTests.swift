import XCTest
@testable import TrueRPCMini

@MainActor
final class OSLogTelemetryServiceTests: XCTestCase {
    func test_track_logsMessageContainingEventName() {
        var capturedMessage: String?
        let sut = OSLogTelemetryService(testSink: { capturedMessage = $0 })

        sut.track(.settingsOpened())

        XCTAssertNotNil(capturedMessage)
        XCTAssertTrue(capturedMessage?.contains("settings_opened") ?? false)
    }

    func test_track_logsMessageContainingAllProperties() {
        var capturedMessage: String?
        let sut = OSLogTelemetryService(testSink: { capturedMessage = $0 })

        sut.track(.appLaunched(appVersion: "1.0.0", osVersion: "15.0"))

        XCTAssertNotNil(capturedMessage)
        let message = capturedMessage ?? ""
        XCTAssertTrue(message.contains("app_launched"))
        XCTAssertTrue(message.contains("app_version=1.0.0"))
        XCTAssertTrue(message.contains("os_version=15.0"))
    }

    func test_track_includesEventPrefix() {
        var capturedMessage: String?
        let sut = OSLogTelemetryService(testSink: { capturedMessage = $0 })

        sut.track(.protoRemoved())

        XCTAssertTrue(capturedMessage?.hasPrefix("[event]") ?? false)
    }
}
