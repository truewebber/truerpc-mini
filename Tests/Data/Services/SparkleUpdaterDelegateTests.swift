import XCTest
@testable import TrueRPCMini

final class SparkleUpdaterDelegateTests: XCTestCase {
    private var sut: SparkleUpdaterDelegate!
    private var logger: MockAppLogger!

    override func setUp() {
        super.setUp()
        logger = MockAppLogger()
        sut = SparkleUpdaterDelegate(logger: logger)
    }

    override func tearDown() {
        sut = nil
        logger = nil
        super.tearDown()
    }

    // MARK: - Update found

    func test_updateFound_logsInfoLevel() {
        sut.logUpdateFound(version: "1.2.0", build: "42")

        XCTAssertEqual(logger.infoMessages.count, 1, "Update found must log at info level")
        XCTAssertTrue(logger.errorMessages.isEmpty)
    }

    func test_updateFound_includesVersionInMetadata() {
        sut.logUpdateFound(version: "2.0.0", build: "100")

        XCTAssertEqual(logger.infoMessages.first?.metadata["version"], "2.0.0")
    }

    func test_updateFound_includesBuildInMetadata() {
        sut.logUpdateFound(version: "2.0.0", build: "100")

        XCTAssertEqual(logger.infoMessages.first?.metadata["build"], "100")
    }

    // MARK: - No update found

    func test_noUpdateFound_logsInfoLevel() {
        sut.logNoUpdateFound()

        XCTAssertEqual(logger.infoMessages.count, 1, "No update found must log at info level")
        XCTAssertTrue(logger.errorMessages.isEmpty)
    }

    func test_noUpdateFound_messageIsNonEmpty() {
        sut.logNoUpdateFound()

        XCTAssertFalse(logger.infoMessages.first?.message.isEmpty ?? true)
    }

    // MARK: - Update error

    func test_updateError_logsErrorLevel() {
        let error = makeError("connection timed out")

        sut.logUpdateError(error)

        XCTAssertEqual(logger.errorMessages.count, 1, "Update error must log at error level")
        XCTAssertTrue(logger.infoMessages.isEmpty)
    }

    func test_updateError_includesErrorDescriptionInMetadata() {
        let error = makeError("connection timed out")

        sut.logUpdateError(error)

        XCTAssertEqual(logger.errorMessages.first?.metadata["error"], "connection timed out")
    }

    // MARK: - Helpers

    private func makeError(_ description: String) -> Error {
        NSError(domain: "SparkleTest", code: 1,
                userInfo: [NSLocalizedDescriptionKey: description])
    }
}
