import XCTest
@testable import TrueRPCMini

final class LoggingTrackerResponseHandlerTests: XCTestCase {
    // MARK: - 200 OK — silent

    func test_handleResponse_whenCode200_doesNotLog() {
        let logger = MockAppLogger()
        let sut = LoggingTrackerResponseHandler(logger: logger)

        sut.handleResponse(eventType: "app_launched", code: 200, message: "success")

        XCTAssertTrue(logger.warningMessages.isEmpty)
        XCTAssertTrue(logger.errorMessages.isEmpty)
        XCTAssertTrue(logger.infoMessages.isEmpty)
        XCTAssertTrue(logger.debugMessages.isEmpty)
    }

    // MARK: - Non-200 — logs warning

    func test_handleResponse_whenCode400_logsWarning() {
        let logger = MockAppLogger()
        let sut = LoggingTrackerResponseHandler(logger: logger)

        sut.handleResponse(eventType: "app_launched", code: 400, message: "bad request")

        XCTAssertEqual(logger.warningMessages.count, 1)
    }

    func test_handleResponse_whenCode429_logsWarning() {
        let logger = MockAppLogger()
        let sut = LoggingTrackerResponseHandler(logger: logger)

        sut.handleResponse(eventType: "request_sent", code: 429, message: "rate limited")

        XCTAssertEqual(logger.warningMessages.count, 1)
    }

    func test_handleResponse_whenCode500_logsWarning() {
        let logger = MockAppLogger()
        let sut = LoggingTrackerResponseHandler(logger: logger)

        sut.handleResponse(eventType: "request_sent", code: 500, message: "server error")

        XCTAssertEqual(logger.warningMessages.count, 1)
    }

    // MARK: - Metadata

    func test_handleResponse_nonOK_includesEventTypeInMetadata() {
        let logger = MockAppLogger()
        let sut = LoggingTrackerResponseHandler(logger: logger)

        sut.handleResponse(eventType: "request_sent", code: 400, message: "error")

        XCTAssertEqual(logger.warningMessages[0].metadata["event"], "request_sent")
    }

    func test_handleResponse_nonOK_includesCodeInMetadata() {
        let logger = MockAppLogger()
        let sut = LoggingTrackerResponseHandler(logger: logger)

        sut.handleResponse(eventType: "app_launched", code: 500, message: "error")

        XCTAssertEqual(logger.warningMessages[0].metadata["code"], "500")
    }

    func test_handleResponse_nonOK_includesMessageInMetadata() {
        let logger = MockAppLogger()
        let sut = LoggingTrackerResponseHandler(logger: logger)

        sut.handleResponse(eventType: "app_launched", code: 429, message: "rate limited")

        XCTAssertEqual(logger.warningMessages[0].metadata["message"], "rate limited")
    }
}
