import XCTest
@testable import TrueRPCMini

@MainActor
final class ImportPathsViewModelTests: XCTestCase {

    var sut: ImportPathsViewModel!
    var mockRepository: MockImportPathsRepositorySpy!

    override func setUp() {
        super.setUp()
        mockRepository = MockImportPathsRepositorySpy()
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_init_loadsPathsFromRepository() {
        // Given
        mockRepository.stubbedPaths = ["/path/a", "/path/b"]

        // When
        sut = ImportPathsViewModel(importPathsRepository: mockRepository)

        // Then
        XCTAssertEqual(sut.paths, ["/path/a", "/path/b"])
        XCTAssertEqual(mockRepository.getImportPathsCallCount, 1)
    }

    func test_init_whenRepositoryEmpty_setsEmptyPaths() {
        // Given
        mockRepository.stubbedPaths = []

        // When
        sut = ImportPathsViewModel(importPathsRepository: mockRepository)

        // Then
        XCTAssertTrue(sut.paths.isEmpty)
    }

    // MARK: - Add Path

    func test_addPath_appendsAndSaves() {
        // Given
        mockRepository.stubbedPaths = ["/existing"]
        sut = ImportPathsViewModel(importPathsRepository: mockRepository)
        let newURL = URL(fileURLWithPath: "/new/directory")

        // When
        sut.addPath(url: newURL)

        // Then
        XCTAssertEqual(sut.paths, ["/existing", "/new/directory"])
        XCTAssertEqual(mockRepository.saveImportPathsCallCount, 1)
        XCTAssertEqual(mockRepository.lastSavedPaths, ["/existing", "/new/directory"])
    }

    func test_addPath_whenEmpty_addsFirstPath() {
        // Given
        mockRepository.stubbedPaths = []
        sut = ImportPathsViewModel(importPathsRepository: mockRepository)
        let url = URL(fileURLWithPath: "/first")

        // When
        sut.addPath(url: url)

        // Then
        XCTAssertEqual(sut.paths, ["/first"])
        XCTAssertEqual(mockRepository.lastSavedPaths, ["/first"])
    }

    // MARK: - Remove Path

    func test_removePath_atIndex_removesAndSaves() {
        // Given
        mockRepository.stubbedPaths = ["/a", "/b", "/c"]
        sut = ImportPathsViewModel(importPathsRepository: mockRepository)

        // When
        sut.removePath(at: 1)

        // Then
        XCTAssertEqual(sut.paths, ["/a", "/c"])
        XCTAssertEqual(mockRepository.lastSavedPaths, ["/a", "/c"])
    }

    func test_removePath_whenIndexOutOfBounds_doesNotModifyPaths() {
        // Given
        mockRepository.stubbedPaths = ["/a", "/b"]
        sut = ImportPathsViewModel(importPathsRepository: mockRepository)

        // When
        sut.removePath(at: 5)

        // Then
        XCTAssertEqual(sut.paths, ["/a", "/b"])
        XCTAssertEqual(mockRepository.saveImportPathsCallCount, 0)
    }
}

// MARK: - Mock

final class MockImportPathsRepositorySpy: ImportPathsRepositoryProtocol {
    var stubbedPaths: [String] = []
    var getImportPathsCallCount = 0
    var saveImportPathsCallCount = 0
    var lastSavedPaths: [String]?

    func getImportPaths() -> [String] {
        getImportPathsCallCount += 1
        return stubbedPaths
    }

    func saveImportPaths(_ paths: [String]) {
        saveImportPathsCallCount += 1
        lastSavedPaths = paths
        stubbedPaths = paths
    }
}
