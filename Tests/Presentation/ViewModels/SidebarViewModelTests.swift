import XCTest
@testable import TrueRPCMini

@MainActor
final class SidebarViewModelTests: XCTestCase {
    
    var sut: SidebarViewModel!
    var mockUseCase: MockImportProtoFileUseCase!
    var mockImportPathsRepository: MockImportPathsRepository!
    var mockProtoPathsPersistence: MockProtoPathsPersistence!
    var mockLoadSavedProtosUseCase: MockLoadSavedProtosUseCase!
    
    override func setUp() {
        super.setUp()
        mockUseCase = MockImportProtoFileUseCase()
        mockImportPathsRepository = MockImportPathsRepository()
        mockProtoPathsPersistence = MockProtoPathsPersistence()
        mockLoadSavedProtosUseCase = MockLoadSavedProtosUseCase()
        sut = SidebarViewModel(
            importProtoFileUseCase: mockUseCase,
            importPathsRepository: mockImportPathsRepository,
            protoPathsPersistence: mockProtoPathsPersistence,
            loadSavedProtosUseCase: mockLoadSavedProtosUseCase
        )
    }
    
    override func tearDown() {
        sut = nil
        mockUseCase = nil
        mockImportPathsRepository = nil
        mockProtoPathsPersistence = nil
        mockLoadSavedProtosUseCase = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func test_init_setsInitialState() {
        // Then
        XCTAssertTrue(sut.protoFiles.isEmpty)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.importPathsCount, 0)
    }

    func test_init_setsImportPathsCountFromRepository() {
        mockImportPathsRepository.importPaths = ["/a", "/b"]

        sut = SidebarViewModel(
            importProtoFileUseCase: mockUseCase,
            importPathsRepository: mockImportPathsRepository,
            protoPathsPersistence: mockProtoPathsPersistence,
            loadSavedProtosUseCase: mockLoadSavedProtosUseCase
        )

        XCTAssertEqual(sut.importPathsCount, 2)
    }

    func test_refreshImportPathsCount_updatesFromRepository() {
        mockImportPathsRepository.importPaths = ["/a"]

        sut.refreshImportPathsCount()

        XCTAssertEqual(sut.importPathsCount, 1)

        mockImportPathsRepository.importPaths = ["/a", "/b", "/c"]
        sut.refreshImportPathsCount()

        XCTAssertEqual(sut.importPathsCount, 3)
    }
    
    // MARK: - Import Success Tests
    
    func test_importProtoFile_whenSuccess_updatesProtoFiles() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/example.proto")
        let expectedProto = ProtoFile(
            name: "example.proto",
            path: testURL,
            services: []
        )
        mockUseCase.mockResultsByURL[testURL] = .success(expectedProto)
        
        // When
        await sut.importProtoFile(url: testURL)
        
        // Then
        XCTAssertEqual(sut.protoFiles.count, 1)
        XCTAssertEqual(sut.protoFiles.first?.name, "example.proto")
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }
    
    func test_importProtoFile_whenSuccess_clearsError() async {
        // Given
        sut.error = "Previous error"
        let testURL = URL(fileURLWithPath: "/test/example.proto")
        mockUseCase.mockResultsByURL[testURL] = .success(ProtoFile(name: "test", path: testURL, services: []))
        
        // When
        await sut.importProtoFile(url: testURL)
        
        // Then
        XCTAssertNil(sut.error)
    }
    
    // MARK: - Import Error Tests
    
    func test_importProtoFile_whenError_setsErrorMessage() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/invalid.proto")
        mockUseCase.mockResultsByURL[testURL] = .failure(TestError.importFailed)
        
        // When
        await sut.importProtoFile(url: testURL)
        
        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.protoFiles.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }
    
    func test_importProtoFile_whenError_doesNotAddToList() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/invalid.proto")
        mockUseCase.mockResultsByURL[testURL] = .failure(TestError.importFailed)
        
        // When
        await sut.importProtoFile(url: testURL)
        
        // Then
        XCTAssertEqual(sut.protoFiles.count, 0)
    }
    
    // MARK: - Multiple Imports Tests
    
    func test_importMultipleFiles_addsAllToList() async {
        // Given
        let url1 = URL(fileURLWithPath: "/test/file1.proto")
        let url2 = URL(fileURLWithPath: "/test/file2.proto")
        
        mockUseCase.mockResultsByURL[url1] = .success(ProtoFile(name: "file1", path: url1, services: []))
        mockUseCase.mockResultsByURL[url2] = .success(ProtoFile(name: "file2", path: url2, services: []))
        
        // When
        await sut.importProtoFile(url: url1)
        await sut.importProtoFile(url: url2)
        
        // Then
        XCTAssertEqual(sut.protoFiles.count, 2)
    }

    func test_importProtoFile_whenSameFileImportedTwice_keepsSingleEntry() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/duplicate.proto")
        let expectedProto = ProtoFile(
            name: "duplicate.proto",
            path: testURL,
            services: []
        )
        mockUseCase.mockResultsByURL[testURL] = .success(expectedProto)

        // When
        await sut.importProtoFile(url: testURL)
        await sut.importProtoFile(url: testURL)

        // Then
        XCTAssertEqual(sut.protoFiles.count, 1)
        XCTAssertEqual(sut.protoFiles.first?.path, testURL)
    }

    func test_loadSavedProtos_whenAlreadyLoaded_doesNotDuplicate() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/saved.proto")
        let existingProto = ProtoFile(
            name: "saved.proto",
            path: testURL,
            services: []
        )
        sut.protoFiles = [existingProto]
        mockProtoPathsPersistence.savedPaths = [testURL]
        mockLoadSavedProtosUseCase.mockProtos = [existingProto]

        // When
        await sut.loadSavedProtos()

        // Then
        XCTAssertEqual(sut.protoFiles.count, 1)
        XCTAssertEqual(sut.protoFiles.first?.path, testURL)
    }
}

// MARK: - Mock ImportPaths Repository

class MockImportPathsRepository: ImportPathsRepositoryProtocol {
    var importPaths: [String] = []
    
    func getImportPaths() -> [String] {
        return importPaths
    }
    
    func saveImportPaths(_ paths: [String]) {
        importPaths = paths
    }
}

// MARK: - Mock ProtoPathsPersistence

class MockProtoPathsPersistence: ProtoPathsPersistenceProtocol {
    var savedPaths: [URL] = []
    
    func saveProtoPaths(_ paths: [URL]) {
        savedPaths = paths
    }
    
    func getProtoPaths() -> [URL] {
        return savedPaths
    }
}

// MARK: - Mock LoadSavedProtosUseCase

class MockLoadSavedProtosUseCase: LoadSavedProtosUseCase {
    var executeCalled = false
    var executeURLs: [URL]?
    var executeImportPaths: [String]?
    var mockProtos: [ProtoFile] = []
    
    init() {
        // Initialize with dummy dependency
        super.init(importProtoFileUseCase: MockImportProtoFileUseCase())
    }
    
    override func execute(urls: [URL], importPaths: [String]) async -> [ProtoFile] {
        executeCalled = true
        executeURLs = urls
        executeImportPaths = importPaths
        return mockProtos
    }
}

private enum TestError: Error {
    case importFailed
    case noProtoFile
}
