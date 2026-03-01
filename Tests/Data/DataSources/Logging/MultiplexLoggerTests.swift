import XCTest
@testable import TrueRPCMini

final class MultiplexLoggerTests: XCTestCase {

    // MARK: - Conformance

    func test_multiplexLogger_conformsToAppLogger() {
        let _: AppLogger = MultiplexLogger([])
    }

    // MARK: - Zero handlers (no-op)

    func test_multiplexLogger_withNoHandlers_doesNotCrash() {
        let sut = MultiplexLogger([])
        sut.debug("d")
        sut.info("i")
        sut.warning("w")
        sut.error("e")
    }

    // MARK: - Dispatches to all handlers

    func test_multiplexLogger_debug_dispatchesToBothHandlers() {
        let a = MockAppLogger()
        let b = MockAppLogger()
        let sut = MultiplexLogger([a, b])

        sut.debug("hello", metadata: ["k": "v"])

        XCTAssertEqual(a.debugMessages.count, 1)
        XCTAssertEqual(b.debugMessages.count, 1)
        XCTAssertEqual(a.debugMessages[0].message, "hello")
        XCTAssertEqual(b.debugMessages[0].message, "hello")
        XCTAssertEqual(a.debugMessages[0].metadata, ["k": "v"])
        XCTAssertEqual(b.debugMessages[0].metadata, ["k": "v"])
    }

    func test_multiplexLogger_info_dispatchesToBothHandlers() {
        let a = MockAppLogger()
        let b = MockAppLogger()
        let sut = MultiplexLogger([a, b])

        sut.info("info msg")

        XCTAssertEqual(a.infoMessages.count, 1)
        XCTAssertEqual(b.infoMessages.count, 1)
        XCTAssertEqual(a.infoMessages[0].message, "info msg")
        XCTAssertEqual(b.infoMessages[0].message, "info msg")
    }

    func test_multiplexLogger_warning_dispatchesToBothHandlers() {
        let a = MockAppLogger()
        let b = MockAppLogger()
        let sut = MultiplexLogger([a, b])

        sut.warning("warn msg")

        XCTAssertEqual(a.warningMessages.count, 1)
        XCTAssertEqual(b.warningMessages.count, 1)
    }

    func test_multiplexLogger_error_dispatchesToBothHandlers() {
        let a = MockAppLogger()
        let b = MockAppLogger()
        let sut = MultiplexLogger([a, b])

        sut.error("err msg")

        XCTAssertEqual(a.errorMessages.count, 1)
        XCTAssertEqual(b.errorMessages.count, 1)
    }

    // MARK: - @autoclosure evaluated exactly once

    func test_multiplexLogger_debug_evaluatesAutoclosureExactlyOnce() {
        let a = MockAppLogger()
        let b = MockAppLogger()
        let sut = MultiplexLogger([a, b])
        var evalCount = 0

        sut.debug({ evalCount += 1; return "msg" }(), metadata: [:])

        XCTAssertEqual(evalCount, 1)
    }

    func test_multiplexLogger_info_evaluatesAutoclosureExactlyOnce() {
        let handlers = (0..<5).map { _ in MockAppLogger() }
        let sut = MultiplexLogger(handlers)
        var evalCount = 0

        sut.info({ evalCount += 1; return "msg" }(), metadata: [:])

        XCTAssertEqual(evalCount, 1)
    }

    func test_multiplexLogger_warning_evaluatesAutoclosureExactlyOnce() {
        let handlers = (0..<3).map { _ in MockAppLogger() }
        let sut = MultiplexLogger(handlers)
        var evalCount = 0

        sut.warning({ evalCount += 1; return "msg" }(), metadata: [:])

        XCTAssertEqual(evalCount, 1)
    }

    func test_multiplexLogger_error_evaluatesAutoclosureExactlyOnce() {
        let handlers = (0..<3).map { _ in MockAppLogger() }
        let sut = MultiplexLogger(handlers)
        var evalCount = 0

        sut.error({ evalCount += 1; return "msg" }(), metadata: [:])

        XCTAssertEqual(evalCount, 1)
    }

    // MARK: - Single handler

    func test_multiplexLogger_withSingleHandler_dispatchesCorrectly() {
        let a = MockAppLogger()
        let sut = MultiplexLogger([a])

        sut.error("single", metadata: ["x": "y"])

        XCTAssertEqual(a.errorMessages.count, 1)
        XCTAssertEqual(a.errorMessages[0].message, "single")
        XCTAssertEqual(a.errorMessages[0].metadata, ["x": "y"])
    }
}
