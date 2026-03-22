import SwiftProtoReflect
import XCTest
@testable import TrueRPCMini

@MainActor
final class RefreshProtoFileUseCaseTests: XCTestCase {
    fileprivate var mockRepository: MockProtoRepositoryForRefresh!
    var sut: RefreshProtoFileUseCase!

    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockProtoRepositoryForRefresh()
        sut = RefreshProtoFileUseCase(repository: mockRepository)
    }

    override func tearDown() async throws {
        sut = nil
        mockRepository = nil
        try await super.tearDown()
    }

    // MARK: - Success Cases

    func test_execute_whenFileExists_returnsUpdatedProtoFile() async throws {
        // Given
        let originalURL = URL(fileURLWithPath: "/protos/service.proto")
        let original = ProtoFile(name: "service.proto", path: originalURL, services: [])

        let updatedMethod = Method(name: "NewMethod", inputType: "Request", outputType: "Response")
        let updatedService = Service(name: "NewService", methods: [updatedMethod])
        let updated = ProtoFile(name: "service.proto", path: originalURL, services: [updatedService])
        mockRepository.protoFileToReturn = updated

        // When
        let result = try await sut.execute(protoFile: original, importPaths: [])

        // Then
        XCTAssertEqual(result.services.count, 1)
        XCTAssertEqual(result.services.first?.name, "NewService")
    }

    func test_execute_whenFileIsMissing_throwsError() async throws {
        // Given
        let url = URL(fileURLWithPath: "/protos/missing.proto")
        let protoFile = ProtoFile(name: "missing.proto", path: url, services: [])
        mockRepository.shouldThrowError = true
        mockRepository.errorToThrow = RefreshProtoError.fileNotFound

        // When / Then
        do {
            _ = try await sut.execute(protoFile: protoFile, importPaths: [])
            XCTFail("Expected error to be thrown")
        } catch let error as RefreshProtoError {
            XCTAssertEqual(error, .fileNotFound)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Repository Interaction

    func test_execute_callsRepositoryWithCorrectURL() async throws {
        // Given
        let expectedURL = URL(fileURLWithPath: "/protos/exact.proto")
        let protoFile = ProtoFile(name: "exact.proto", path: expectedURL, services: [])
        mockRepository.protoFileToReturn = ProtoFile(name: "exact.proto", path: expectedURL, services: [])

        // When
        _ = try await sut.execute(protoFile: protoFile, importPaths: [])

        // Then
        XCTAssertTrue(mockRepository.loadProtoCalled)
        XCTAssertEqual(mockRepository.loadProtoURL, expectedURL)
    }

    func test_execute_callsRepositoryWithCorrectImportPaths() async throws {
        // Given
        let url = URL(fileURLWithPath: "/protos/dep.proto")
        let protoFile = ProtoFile(name: "dep.proto", path: url, services: [])
        let expectedImportPaths = ["/vendor/protos", "/common/protos"]
        mockRepository.protoFileToReturn = ProtoFile(name: "dep.proto", path: url, services: [])

        // When
        _ = try await sut.execute(protoFile: protoFile, importPaths: expectedImportPaths)

        // Then
        XCTAssertEqual(mockRepository.loadProtoImportPaths, expectedImportPaths)
    }
}

// MARK: - Mock

@MainActor
private final class MockProtoRepositoryForRefresh: ProtoRepositoryProtocol {
    var loadProtoCalled = false
    var loadProtoURL: URL?
    var loadProtoImportPaths: [String]?
    var protoFileToReturn: ProtoFile?
    var shouldThrowError = false
    var errorToThrow: Error = RefreshProtoError.fileNotFound

    func loadProto(url: URL) throws -> ProtoFile {
        loadProtoCalled = true
        loadProtoURL = url
        loadProtoImportPaths = nil
        if shouldThrowError { throw errorToThrow }
        guard let protoFile = protoFileToReturn else { throw RefreshProtoError.fileNotFound }

        return protoFile
    }

    func loadProto(url: URL, importPaths: [String]) throws -> ProtoFile {
        loadProtoCalled = true
        loadProtoURL = url
        loadProtoImportPaths = importPaths
        if shouldThrowError { throw errorToThrow }
        guard let protoFile = protoFileToReturn else { throw RefreshProtoError.fileNotFound }

        return protoFile
    }

    func getLoadedProtos() -> [ProtoFile] {
        protoFileToReturn.map { [$0] } ?? []
    }

    func getMessageDescriptor(forType _: String, in _: ProtoFile) throws -> MessageDescriptor {
        let fileDesc = FileDescriptor(name: "mock.proto", package: "mock")
        return MessageDescriptor(name: "MockMessage", parent: fileDesc)
    }
}

// MARK: - Test Error

private enum RefreshProtoError: Error, Equatable {
    case fileNotFound
}
