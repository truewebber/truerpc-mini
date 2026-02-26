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

// MARK: - Import Paths Tests

extension FileSystemProtoRepositoryTests {
    func test_loadProto_withImportPaths_parsesFileWithDependencies() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let commonDir = tempDir.appendingPathComponent("common")
        try? FileManager.default.createDirectory(at: commonDir, withIntermediateDirectories: true)
        
        let commonTypesContent = """
        syntax = "proto3";
        
        package common;
        
        message Timestamp {
            int64 seconds = 1;
            int32 nanos = 2;
        }
        """
        let commonTypesURL = commonDir.appendingPathComponent("types.proto")
        try commonTypesContent.write(to: commonTypesURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: commonTypesURL) }
        
        let mainProtoContent = """
        syntax = "proto3";
        
        package test;
        
        import "common/types.proto";
        
        message User {
            string id = 1;
            string name = 2;
            common.Timestamp created_at = 3;
        }
        
        service UserService {
            rpc GetUser (GetUserRequest) returns (User);
        }
        
        message GetUserRequest {
            string id = 1;
        }
        """
        let mainProtoURL = try createTempProtoFile(content: mainProtoContent, name: "test_with_import.proto")
        defer { try? FileManager.default.removeItem(at: mainProtoURL) }
        
        // When
        let protoFile = try await sut.loadProto(url: mainProtoURL, importPaths: [tempDir.path])
        
        // Then
        XCTAssertEqual(protoFile.name, "test_with_import.proto")
        XCTAssertEqual(protoFile.services.count, 1)
        XCTAssertEqual(protoFile.services.first?.name, "UserService")
    }
    
    func test_loadProto_withEmptyImportPaths_failsForFileWithDependencies() async {
        // Given
        let mainProtoContent = """
        syntax = "proto3";
        
        package test;
        
        import "common/types.proto";
        
        message User {
            string id = 1;
        }
        """
        let mainProtoURL = try! createTempProtoFile(content: mainProtoContent, name: "test_with_import.proto")
        defer { try? FileManager.default.removeItem(at: mainProtoURL) }
        
        // When/Then
        do {
            _ = try await sut.loadProto(url: mainProtoURL, importPaths: [])
            XCTFail("Expected parsing to fail without import paths")
        } catch {
            // Success - should fail
            XCTAssertTrue(error is ProtoRepositoryError)
        }
    }
    
    func test_loadProto_withMultipleImportPaths_findsCorrectDependency() async throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let commonDir = tempDir.appendingPathComponent("common")
        try? FileManager.default.createDirectory(at: commonDir, withIntermediateDirectories: true)
        
        // Create another empty directory to test multiple paths
        let emptyDir = tempDir.appendingPathComponent("empty_protos")
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDir) }
        
        let commonTypesContent = """
        syntax = "proto3";
        
        package common;
        
        message Timestamp {
            int64 seconds = 1;
            int32 nanos = 2;
        }
        """
        let commonTypesURL = commonDir.appendingPathComponent("types.proto")
        try commonTypesContent.write(to: commonTypesURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: commonTypesURL) }
        
        let mainProtoContent = """
        syntax = "proto3";
        
        package test;
        
        import "common/types.proto";
        
        message User {
            string id = 1;
            common.Timestamp created_at = 2;
        }
        
        service UserService {
            rpc GetUser (GetUserRequest) returns (User);
        }
        
        message GetUserRequest {
            string id = 1;
        }
        """
        let mainProtoURL = try createTempProtoFile(content: mainProtoContent, name: "test_with_import2.proto")
        defer { try? FileManager.default.removeItem(at: mainProtoURL) }
        
        // When - First path is empty but valid, second contains the dependency
        let protoFile = try await sut.loadProto(url: mainProtoURL, importPaths: [emptyDir.path, tempDir.path])
        
        // Then
        XCTAssertEqual(protoFile.name, "test_with_import2.proto")
        XCTAssertEqual(protoFile.services.count, 1)
    }
}

// MARK: - Message Descriptor Tests

extension FileSystemProtoRepositoryTests {
    func test_getMessageDescriptor_whenTypeExists_returnsDescriptor() async throws {
        // Given
        let testProtoContent = """
        syntax = "proto3";
        package test;
        
        message TestMessage {
          string value = 1;
          int32 count = 2;
        }
        
        service TestService {
          rpc TestMethod(TestMessage) returns (TestMessage);
        }
        """
        
        let tempURL = try createTempProtoFile(content: testProtoContent, name: "test_desc.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = try await sut.loadProto(url: tempURL)
        
        // When
        let descriptor = try sut.getMessageDescriptor(forType: ".test.TestMessage")
        
        // Then
        XCTAssertEqual(descriptor.name, "TestMessage")
        XCTAssertEqual(descriptor.fields.count, 2)
    }
    
    func test_getMessageDescriptor_whenTypeNotFound_throwsError() async throws {
        // Given
        let testProtoContent = """
        syntax = "proto3";
        
        message ExistingMessage {
          string value = 1;
        }
        """
        
        let tempURL = try createTempProtoFile(content: testProtoContent, name: "test_missing.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = try await sut.loadProto(url: tempURL)
        
        // When/Then
        XCTAssertThrowsError(try sut.getMessageDescriptor(forType: ".NonExistent")) { error in
            guard case ProtoRepositoryError.messageTypeNotFound = error else {
                XCTFail("Expected messageTypeNotFound error")
                return
            }
        }
    }
    
    func test_getMessageDescriptor_withNoLoadedProtos_throwsError() throws {
        // Given - no protos loaded
        
        // When/Then
        XCTAssertThrowsError(try sut.getMessageDescriptor(forType: ".test.Message")) { error in
            guard case ProtoRepositoryError.messageTypeNotFound = error else {
                XCTFail("Expected messageTypeNotFound error")
                return
            }
        }
    }
    
    func test_getMessageDescriptor_whenTypeIsCrossPackage_resolvesGoogleProtobufEmpty() async throws {
        // Given - load google.protobuf.Empty (as from receiver.proto with import "google/protobuf/empty.proto")
        let tempDir = FileManager.default.temporaryDirectory
        let googleProtobufDir = tempDir.appendingPathComponent("google").appendingPathComponent("protobuf")
        try FileManager.default.createDirectory(at: googleProtobufDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("google")) }
        
        let emptyProtoContent = """
        syntax = "proto3";
        package google.protobuf;
        message Empty {}
        """
        let emptyProtoURL = googleProtobufDir.appendingPathComponent("empty.proto")
        try emptyProtoContent.write(to: emptyProtoURL, atomically: true, encoding: .utf8)
        
        _ = try await sut.loadProto(url: emptyProtoURL)
        
        // When
        let descriptor = try sut.getMessageDescriptor(forType: ".google.protobuf.Empty")
        
        // Then - should resolve to google.protobuf.Empty
        XCTAssertEqual(descriptor.name, "Empty")
        XCTAssertEqual(descriptor.fields.count, 0)
    }

    func test_getMessageDescriptor_whenTypeHasWronglyPrefixedPackage_throwsError() async throws {
        // Given - load google.protobuf.Empty
        let tempDir = FileManager.default.temporaryDirectory
        let googleProtobufDir = tempDir.appendingPathComponent("google").appendingPathComponent("protobuf")
        try FileManager.default.createDirectory(at: googleProtobufDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir.appendingPathComponent("google")) }

        let emptyProtoContent = """
        syntax = "proto3";
        package google.protobuf;
        message Empty {}
        """
        let emptyProtoURL = googleProtobufDir.appendingPathComponent("empty.proto")
        try emptyProtoContent.write(to: emptyProtoURL, atomically: true, encoding: .utf8)

        _ = try await sut.loadProto(url: emptyProtoURL)

        // When/Then - wrong package prefix should not resolve
        XCTAssertThrowsError(
            try sut.getMessageDescriptor(forType: ".mattis.dev.v1.regionspy.google.protobuf.Empty")
        ) { error in
            guard case ProtoRepositoryError.messageTypeNotFound = error else {
                XCTFail("Expected messageTypeNotFound error")
                return
            }
        }
    }
}
