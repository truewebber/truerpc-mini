import os
import XCTest
@testable import TrueRPCMini

// MARK: - Mock

private final class MockSentryWriter: SentryLogWriterProtocol, Sendable {
    struct WriteCall {
        let level: AppLogLevel
        let message: String
        let attributes: [String: String]
    }

    private struct Storage {
        var calls: [WriteCall] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    var calls: [WriteCall] {
        storage.withLock { $0.calls }
    }

    func write(level: AppLogLevel, message: String, attributes: [String: Any]) {
        let stringAttributes = attributes.compactMapValues { $0 as? String }
        storage.withLock { $0.calls.append(WriteCall(level: level, message: message, attributes: stringAttributes)) }
    }
}

// MARK: - Tests

final class SentryLoggerTests: XCTestCase {
    // MARK: - Protocol conformance

    func test_sentryLogger_conformsToAppLogger() {
        let _: AppLogger = SentryLogger(minLevel: .error, writer: MockSentryWriter())
    }

    // MARK: - minLevel filtering (minLevel = .error)

    func test_sentryLogger_whenMinLevelIsError_debugDoesNotReachWriter() {
        let writer = MockSentryWriter()
        let sut = SentryLogger(minLevel: .error, writer: writer)

        sut.debug("should be blocked")

        XCTAssertTrue(writer.calls.isEmpty)
    }

    func test_sentryLogger_whenMinLevelIsError_infoDoesNotReachWriter() {
        let writer = MockSentryWriter()
        let sut = SentryLogger(minLevel: .error, writer: writer)

        sut.info("should be blocked")

        XCTAssertTrue(writer.calls.isEmpty)
    }

    func test_sentryLogger_whenMinLevelIsError_warningDoesNotReachWriter() {
        let writer = MockSentryWriter()
        let sut = SentryLogger(minLevel: .error, writer: writer)

        sut.warning("should be blocked")

        XCTAssertTrue(writer.calls.isEmpty)
    }

    func test_sentryLogger_whenMinLevelIsError_errorReachesWriter() {
        let writer = MockSentryWriter()
        let sut = SentryLogger(minLevel: .error, writer: writer)

        sut.error("should pass")

        XCTAssertEqual(writer.calls.count, 1)
        XCTAssertEqual(writer.calls[0].level, .error)
        XCTAssertEqual(writer.calls[0].message, "should pass")
    }

    // MARK: - minLevel filtering (minLevel = .debug)

    func test_sentryLogger_whenMinLevelIsDebug_allLevelsReachWriter() {
        let writer = MockSentryWriter()
        let sut = SentryLogger(minLevel: .debug, writer: writer)

        sut.debug("d")
        sut.info("i")
        sut.warning("w")
        sut.error("e")

        XCTAssertEqual(writer.calls.count, 4)
        XCTAssertEqual(writer.calls[0].level, .debug)
        XCTAssertEqual(writer.calls[1].level, .info)
        XCTAssertEqual(writer.calls[2].level, .warning)
        XCTAssertEqual(writer.calls[3].level, .error)
    }

    func test_sentryLogger_whenMinLevelIsWarning_onlyWarningAndErrorReachWriter() {
        let writer = MockSentryWriter()
        let sut = SentryLogger(minLevel: .warning, writer: writer)

        sut.debug("blocked")
        sut.info("blocked")
        sut.warning("passes")
        sut.error("passes")

        XCTAssertEqual(writer.calls.count, 2)
        XCTAssertEqual(writer.calls[0].level, .warning)
        XCTAssertEqual(writer.calls[1].level, .error)
    }

    // MARK: - Metadata conversion to attributes

    func test_sentryLogger_metadata_isPassedAsStringAttributes() {
        let writer = MockSentryWriter()
        let sut = SentryLogger(minLevel: .debug, writer: writer)

        sut.error("msg", metadata: ["userId": "abc", "code": "404"])

        XCTAssertEqual(writer.calls.count, 1)
        XCTAssertEqual(writer.calls[0].attributes["userId"], "abc")
        XCTAssertEqual(writer.calls[0].attributes["code"], "404")
    }

    func test_sentryLogger_emptyMetadata_isPassedAsEmptyAttributes() {
        let writer = MockSentryWriter()
        let sut = SentryLogger(minLevel: .debug, writer: writer)

        sut.error("msg", metadata: [:])

        XCTAssertEqual(writer.calls.count, 1)
        XCTAssertTrue(writer.calls[0].attributes.isEmpty)
    }

    func test_sentryLogger_message_isPassedToWriter() {
        let writer = MockSentryWriter()
        let sut = SentryLogger(minLevel: .debug, writer: writer)

        sut.info("hello world")

        XCTAssertEqual(writer.calls[0].message, "hello world")
    }
}
