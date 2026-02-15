import XCTest
@testable import TrueRPCMini

final class FileSystemProtoRepositoryTests: XCTestCase {
    
    var sut: FileSystemProtoRepository!
    
    override func setUp() {
        super.setUp()
        sut = FileSystemProtoRepository()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Success Cases
    
    func test_loadProto_whenValidFile_returnsProtoFile() async throws {
        // Given
        let testProtoContent = """
        syntax = "proto3";
        package test;
        
        message TestMessage {
          string value = 1;
        }
        
        service TestService {
          rpc TestMethod(TestMessage) returns (TestMessage);
        }
        """
        
        let tempURL = try createTempProtoFile(content: testProtoContent, name: "test.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // When
        let result = try await sut.loadProto(url: tempURL)
        
        // Then
        XCTAssertEqual(result.name, "test.proto")
        XCTAssertEqual(result.path, tempURL)
        XCTAssertEqual(result.services.count, 1)
        XCTAssertEqual(result.services.first?.name, "TestService")
        XCTAssertEqual(result.services.first?.methods.count, 1)
        XCTAssertEqual(result.services.first?.methods.first?.name, "TestMethod")
    }
    
    func test_loadProto_whenMultipleServices_parsesAll() async throws {
        // Given
        let testProtoContent = """
        syntax = "proto3";
        
        message Request {}
        message Response {}
        
        service ServiceA {
          rpc MethodA(Request) returns (Response);
        }
        
        service ServiceB {
          rpc MethodB(Request) returns (Response);
        }
        """
        
        let tempURL = try createTempProtoFile(content: testProtoContent, name: "multi.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // When
        let result = try await sut.loadProto(url: tempURL)
        
        // Then
        XCTAssertEqual(result.services.count, 2)
        XCTAssertTrue(result.services.contains { $0.name == "ServiceA" })
        XCTAssertTrue(result.services.contains { $0.name == "ServiceB" })
    }
    
    func test_getLoadedProtos_afterLoadingProto_returnsLoadedFiles() async throws {
        // Given
        let content = """
        syntax = "proto3";
        service TestService {}
        """
        let tempURL = try createTempProtoFile(content: content, name: "loaded.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // When
        let loaded = try await sut.loadProto(url: tempURL)
        let protos = sut.getLoadedProtos()
        
        // Then
        XCTAssertEqual(protos.count, 1)
        XCTAssertEqual(protos.first?.id, loaded.id)
    }
    
    func test_getLoadedProtos_withNoLoaded_returnsEmpty() {
        // Given/When
        let protos = sut.getLoadedProtos()
        
        // Then
        XCTAssertEqual(protos.count, 0)
    }
    
    // MARK: - Error Cases
    
    func test_loadProto_whenFileNotFound_throwsError() async throws {
        // Given
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/file.proto")
        
        // When/Then
        do {
            _ = try await sut.loadProto(url: nonExistentURL)
            XCTFail("Should throw error")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    func test_loadProto_whenInvalidProtoSyntax_throwsError() async throws {
        // Given
        let invalidContent = "this is not valid proto syntax"
        let tempURL = try createTempProtoFile(content: invalidContent, name: "invalid.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // When/Then
        do {
            _ = try await sut.loadProto(url: tempURL)
            XCTFail("Should throw error for invalid syntax")
        } catch {
            // Expected error
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Helpers
    
    private func createTempProtoFile(content: String, name: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
