import XCTest
@testable import TrueRPCMini

/// Tests for UserDefaultsProtoPathsRepository - persisting proto file paths
final class UserDefaultsProtoPathsRepositoryTests: XCTestCase {
    var sut: UserDefaultsProtoPathsRepository!
    var userDefaults: UserDefaults!
    var mockLogger: MockAppLogger!
    let testKey = "com.truewebber.TrueRPCMini.test.protoPaths"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "test-proto-paths")!
        userDefaults.removePersistentDomain(forName: "test-proto-paths")
        mockLogger = MockAppLogger()
        sut = UserDefaultsProtoPathsRepository(userDefaults: userDefaults, key: testKey, logger: mockLogger)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "test-proto-paths")
        sut = nil
        userDefaults = nil
        mockLogger = nil
        super.tearDown()
    }

    // MARK: - Save & Load Tests

    func test_saveAndGet_storesPaths() {
        // Given
        let url1 = URL(fileURLWithPath: "/path/to/proto1.proto")
        let url2 = URL(fileURLWithPath: "/path/to/proto2.proto")
        let urls = [url1, url2]

        // When
        sut.saveProtoPaths(urls)
        let retrieved = sut.getProtoPaths()

        // Then
        XCTAssertEqual(retrieved.count, 2)
        XCTAssertEqual(retrieved[0], url1)
        XCTAssertEqual(retrieved[1], url2)
    }

    func test_saveEmptyArray_storesEmptyArray() {
        // Given
        sut.saveProtoPaths([URL(fileURLWithPath: "/test.proto")])

        // When
        sut.saveProtoPaths([])
        let retrieved = sut.getProtoPaths()

        // Then
        XCTAssertTrue(retrieved.isEmpty)
    }

    func test_getProtoPaths_whenNothingSaved_returnsEmptyArray() {
        // When
        let retrieved = sut.getProtoPaths()

        // Then
        XCTAssertTrue(retrieved.isEmpty)
    }

    func test_save_overwritesPreviousPaths() {
        // Given
        let url1 = URL(fileURLWithPath: "/path/to/proto1.proto")
        let url2 = URL(fileURLWithPath: "/path/to/proto2.proto")

        sut.saveProtoPaths([url1])

        // When
        sut.saveProtoPaths([url2])
        let retrieved = sut.getProtoPaths()

        // Then
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved[0], url2)
    }

    // MARK: - Persistence Tests

    func test_persistsAcrossInstances() {
        // Given
        let url = URL(fileURLWithPath: "/path/to/test.proto")
        sut.saveProtoPaths([url])

        // When
        let newRepository = UserDefaultsProtoPathsRepository(
            userDefaults: userDefaults,
            key: testKey,
            logger: MockAppLogger())
        let retrieved = newRepository.getProtoPaths()

        // Then
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved[0], url)
    }

    // MARK: - Edge Cases

    func test_savePathsWithSpecialCharacters() {
        // Given
        let url = URL(fileURLWithPath: "/path/with spaces/файл.proto")

        // When
        sut.saveProtoPaths([url])
        let retrieved = sut.getProtoPaths()

        // Then
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved[0], url)
    }

    // MARK: - Logger

    func test_saveProtoPaths_logsDebugWithCount() {
        let urls = [URL(fileURLWithPath: "/a.proto"), URL(fileURLWithPath: "/b.proto")]

        sut.saveProtoPaths(urls)

        XCTAssertEqual(mockLogger.debugMessages.count, 1)
        XCTAssertEqual(mockLogger.debugMessages[0].metadata["count"], "2")
    }

    func test_getProtoPaths_whenPathsExist_logsDebugWithCount() {
        let url = URL(fileURLWithPath: "/a.proto")
        sut.saveProtoPaths([url])

        let freshLogger = MockAppLogger()
        let freshSut = UserDefaultsProtoPathsRepository(userDefaults: userDefaults, key: testKey, logger: freshLogger)

        _ = freshSut.getProtoPaths()

        XCTAssertEqual(freshLogger.debugMessages.count, 1)
        XCTAssertEqual(freshLogger.debugMessages[0].metadata["count"], "1")
    }

    func test_getProtoPaths_whenEmpty_doesNotLog() {
        _ = sut.getProtoPaths()

        XCTAssertTrue(mockLogger.debugMessages.isEmpty)
    }

    func test_saveLargeNumberOfPaths() {
        // Given
        let urls = (0 ..< 100).map { URL(fileURLWithPath: "/path/to/proto\($0).proto") }

        // When
        sut.saveProtoPaths(urls)
        let retrieved = sut.getProtoPaths()

        // Then
        XCTAssertEqual(retrieved.count, 100)
        XCTAssertEqual(retrieved, urls)
    }
}
