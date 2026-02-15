import XCTest
@testable import TrueRPCMini

/// Tests for LoadSavedProtosUseCase - loading proto files from saved paths
final class LoadSavedProtosUseCaseTests: XCTestCase {
    var sut: LoadSavedProtosUseCase!
    var mockImportUseCase: MockImportProtoFileUseCase!
    
    override func setUp() {
        super.setUp()
        mockImportUseCase = MockImportProtoFileUseCase()
        sut = LoadSavedProtosUseCase(importProtoFileUseCase: mockImportUseCase)
    }
    
    override func tearDown() {
        sut = nil
        mockImportUseCase = nil
        super.tearDown()
    }
    
    // MARK: - Happy Path
    
    func test_execute_withValidURLs_returnsAllProtoFiles() async throws {
        // Given
        let url1 = URL(fileURLWithPath: "/path/to/proto1.proto")
        let url2 = URL(fileURLWithPath: "/path/to/proto2.proto")
        let urls = [url1, url2]
        
        let proto1 = ProtoFile(name: "proto1.proto", path: url1, services: [])
        let proto2 = ProtoFile(name: "proto2.proto", path: url2, services: [])
        
        mockImportUseCase.mockResultsByURL[url1] = .success(proto1)
        mockImportUseCase.mockResultsByURL[url2] = .success(proto2)
        
        // When
        let result = await sut.execute(urls: urls, importPaths: [])
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "proto1.proto")
        XCTAssertEqual(result[1].name, "proto2.proto")
        XCTAssertEqual(mockImportUseCase.callCount, 2)
    }
    
    func test_execute_withImportPaths_passesThemToUseCase() async throws {
        // Given
        let url = URL(fileURLWithPath: "/path/to/proto.proto")
        let importPaths = ["/path/to/imports"]
        let proto = ProtoFile(name: "proto.proto", path: url, services: [])
        
        mockImportUseCase.mockResultsByURL[url] = .success(proto)
        
        // When
        let result = await sut.execute(urls: [url], importPaths: importPaths)
        
        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(mockImportUseCase.lastImportPaths, importPaths)
    }
    
    func test_execute_withEmptyURLs_returnsEmptyArray() async throws {
        // Given
        let urls: [URL] = []
        
        // When
        let result = await sut.execute(urls: urls, importPaths: [])
        
        // Then
        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(mockImportUseCase.callCount, 0)
    }
    
    // MARK: - Error Handling (Silent Skip)
    
    func test_execute_whenOneFileFails_skipsItAndContinues() async throws {
        // Given
        let url1 = URL(fileURLWithPath: "/path/to/proto1.proto")
        let url2 = URL(fileURLWithPath: "/path/to/proto2.proto")
        let url3 = URL(fileURLWithPath: "/path/to/proto3.proto")
        let urls = [url1, url2, url3]
        
        let proto1 = ProtoFile(name: "proto1.proto", path: url1, services: [])
        let proto3 = ProtoFile(name: "proto3.proto", path: url3, services: [])
        
        mockImportUseCase.mockResultsByURL[url1] = .success(proto1)
        mockImportUseCase.mockResultsByURL[url2] = .failure(NSError(domain: "test", code: 404))
        mockImportUseCase.mockResultsByURL[url3] = .success(proto3)
        
        // When
        let result = await sut.execute(urls: urls, importPaths: [])
        
        // Then
        XCTAssertEqual(result.count, 2, "Should load 2 successful protos, skip 1 failed")
        XCTAssertEqual(result[0].name, "proto1.proto")
        XCTAssertEqual(result[1].name, "proto3.proto")
        XCTAssertEqual(mockImportUseCase.callCount, 3, "Should attempt all 3")
    }
    
    func test_execute_whenAllFilesFail_returnsEmptyArray() async throws {
        // Given
        let url1 = URL(fileURLWithPath: "/path/to/proto1.proto")
        let url2 = URL(fileURLWithPath: "/path/to/proto2.proto")
        let urls = [url1, url2]
        
        mockImportUseCase.mockResultsByURL[url1] = .failure(NSError(domain: "test", code: 404))
        mockImportUseCase.mockResultsByURL[url2] = .failure(NSError(domain: "test", code: 500))
        
        // When
        let result = await sut.execute(urls: urls, importPaths: [])
        
        // Then
        XCTAssertEqual(result.count, 0)
        XCTAssertEqual(mockImportUseCase.callCount, 2)
    }
}
