import XCTest
@testable import TrueRPCMini

final class ImportProtoFileUseCaseTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Success Cases
    
    func test_execute_whenValidURL_returnsProtoFile() async throws {
        // Given
        let mockRepository = MockProtoRepository()
        let sut = ImportProtoFileUseCase(repository: mockRepository)
        let testURL = URL(fileURLWithPath: "/test/example.proto")
        
        let expectedProtoFile = ProtoFile(
            name: "example.proto",
            path: testURL,
            services: []
        )
        mockRepository.protoFileToReturn = expectedProtoFile
        
        // When
        let result = try await sut.execute(url: testURL)
        
        // Then
        XCTAssertEqual(result, expectedProtoFile)
        XCTAssertTrue(mockRepository.loadProtoCalled)
        XCTAssertEqual(mockRepository.loadProtoURL, testURL)
    }
    
    func test_execute_whenProtoWithServices_returnsCompleteStructure() async throws {
        // Given
        let mockRepository = MockProtoRepository()
        let sut = ImportProtoFileUseCase(repository: mockRepository)
        let testURL = URL(fileURLWithPath: "/test/service.proto")
        
        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse"
        )
        let service = Service(name: "UserService", methods: [method])
        let expectedProtoFile = ProtoFile(
            name: "service.proto",
            path: testURL,
            services: [service]
        )
        mockRepository.protoFileToReturn = expectedProtoFile
        
        // When
        let result = try await sut.execute(url: testURL)
        
        // Then
        XCTAssertEqual(result.services.count, 1)
        XCTAssertEqual(result.services.first?.name, "UserService")
        XCTAssertEqual(result.services.first?.methods.count, 1)
        XCTAssertEqual(result.services.first?.methods.first?.name, "GetUser")
    }
    
    // MARK: - Error Cases
    
    func test_execute_whenRepositoryThrows_propagatesError() async throws {
        // Given
        let mockRepository = MockProtoRepository()
        let sut = ImportProtoFileUseCase(repository: mockRepository)
        let testURL = URL(fileURLWithPath: "/test/invalid.proto")
        
        mockRepository.shouldThrowError = true
        
        // When/Then
        do {
            _ = try await sut.execute(url: testURL)
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(mockRepository.loadProtoCalled)
            XCTAssertNotNil(error)
        }
    }
    
    func test_execute_whenFileNotFound_throwsError() async throws {
        // Given
        let mockRepository = MockProtoRepository()
        let sut = ImportProtoFileUseCase(repository: mockRepository)
        let testURL = URL(fileURLWithPath: "/nonexistent/file.proto")
        
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = ProtoError.fileNotFound
        
        // When/Then
        do {
            _ = try await sut.execute(url: testURL)
            XCTFail("Should throw fileNotFound error")
        } catch let error as ProtoError {
            XCTAssertEqual(error, ProtoError.fileNotFound)
        } catch {
            XCTFail("Should throw ProtoError.fileNotFound")
        }
    }
}

// MARK: - Mock Repository

private class MockProtoRepository: ProtoRepositoryProtocol {
    var loadProtoCalled = false
    var loadProtoURL: URL?
    var protoFileToReturn: ProtoFile?
    var shouldThrowError = false
    var errorToThrow: Error = ProtoError.invalidFormat
    
    func loadProto(url: URL) async throws -> ProtoFile {
        loadProtoCalled = true
        loadProtoURL = url
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        guard let protoFile = protoFileToReturn else {
            throw ProtoError.invalidFormat
        }
        
        return protoFile
    }
    
    func getLoadedProtos() -> [ProtoFile] {
        return protoFileToReturn.map { [$0] } ?? []
    }
}

// MARK: - Test Error Types

private enum ProtoError: Error, Equatable {
    case fileNotFound
    case invalidFormat
}
