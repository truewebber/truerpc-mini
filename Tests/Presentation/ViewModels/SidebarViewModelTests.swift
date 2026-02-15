import XCTest
@testable import TrueRPCMini

@MainActor
final class SidebarViewModelTests: XCTestCase {
    
    var sut: SidebarViewModel!
    var mockUseCase: MockImportProtoFileUseCase!
    
    override func setUp() {
        super.setUp()
        mockUseCase = MockImportProtoFileUseCase()
        sut = SidebarViewModel(importProtoFileUseCase: mockUseCase)
    }
    
    override func tearDown() {
        sut = nil
        mockUseCase = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func test_init_setsInitialState() {
        // Then
        XCTAssertTrue(sut.protoFiles.isEmpty)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
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
        mockUseCase.protoFileToReturn = expectedProto
        
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
        mockUseCase.protoFileToReturn = ProtoFile(name: "test", path: testURL, services: [])
        
        // When
        await sut.importProtoFile(url: testURL)
        
        // Then
        XCTAssertNil(sut.error)
    }
    
    // MARK: - Import Error Tests
    
    func test_importProtoFile_whenError_setsErrorMessage() async {
        // Given
        let testURL = URL(fileURLWithPath: "/test/invalid.proto")
        mockUseCase.shouldThrowError = true
        
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
        mockUseCase.shouldThrowError = true
        
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
        
        // When
        mockUseCase.protoFileToReturn = ProtoFile(name: "file1", path: url1, services: [])
        await sut.importProtoFile(url: url1)
        
        mockUseCase.protoFileToReturn = ProtoFile(name: "file2", path: url2, services: [])
        await sut.importProtoFile(url: url2)
        
        // Then
        XCTAssertEqual(sut.protoFiles.count, 2)
    }
}

// MARK: - Mock Use Case

class MockImportProtoFileUseCase: ImportProtoFileUseCaseProtocol {
    var executeCalled = false
    var executeURL: URL?
    var protoFileToReturn: ProtoFile?
    var shouldThrowError = false
    
    func execute(url: URL) async throws -> ProtoFile {
        executeCalled = true
        executeURL = url
        
        if shouldThrowError {
            throw TestError.importFailed
        }
        
        guard let protoFile = protoFileToReturn else {
            throw TestError.noProtoFile
        }
        
        return protoFile
    }
}

private enum TestError: Error {
    case importFailed
    case noProtoFile
}
