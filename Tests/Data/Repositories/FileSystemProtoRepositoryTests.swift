import XCTest
@testable import TrueRPCMini

final class FileSystemProtoRepositoryTests: XCTestCase {
    var sut: FileSystemProtoRepository!
    var mockLogger: MockAppLogger!

    override func setUp() {
        super.setUp()
        mockLogger = MockAppLogger()
        sut = FileSystemProtoRepository(logger: mockLogger)
    }

    override func tearDown() {
        sut = nil
        mockLogger = nil
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

    func test_loadProto_withEmptyImportPaths_failsForFileWithDependencies() async throws {
        // Given
        let mainProtoContent = """
        syntax = "proto3";

        package test;

        import "common/types.proto";

        message User {
            string id = 1;
        }
        """
        let mainProtoURL = try createTempProtoFile(content: mainProtoContent, name: "test_with_import.proto")
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

    // MARK: - Logger error path

    func test_loadProto_whenParsingFails_logsErrorWithFileName() async throws {
        let invalidContent = "not valid proto"
        let tempURL = try createTempProtoFile(content: invalidContent, name: "bad.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try? await sut.loadProto(url: tempURL)

        XCTAssertEqual(mockLogger.errorMessages.count, 1)
        XCTAssertEqual(mockLogger.errorMessages[0].metadata["file"], "bad.proto")
        XCTAssertNotNil(mockLogger.errorMessages[0].metadata["error"])
    }

    func test_loadProto_whenParsingFails_logsErrorWithDependenciesCount() async throws {
        let invalidContent = "not valid proto"
        let tempURL = try createTempProtoFile(content: invalidContent, name: "bad_deps.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try? await sut.loadProto(url: tempURL)

        XCTAssertEqual(mockLogger.errorMessages[0].metadata["dependencies_count"], "0")
    }

    func test_loadProto_whenParsingFails_logsMissingImports() async throws {
        let invalidContent = "not valid proto"
        let tempURL = try createTempProtoFile(content: invalidContent, name: "bad_imports.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try? await sut.loadProto(url: tempURL)

        XCTAssertNotNil(mockLogger.errorMessages[0].metadata["missing_imports"])
    }

    func test_loadProto_withImportPaths_whenParsingFails_logsDependenciesCount() async throws {
        let invalidContent = "not valid proto"
        let tempURL = try createTempProtoFile(content: invalidContent, name: "bad2.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try? await sut.loadProto(url: tempURL, importPaths: ["/path/a", "/path/b"])

        XCTAssertEqual(mockLogger.errorMessages.count, 1)
        XCTAssertEqual(mockLogger.errorMessages[0].metadata["file"], "bad2.proto")
        XCTAssertEqual(mockLogger.errorMessages[0].metadata["dependencies_count"], "2")
    }

    func test_loadProto_withImportPaths_whenDependencyMissing_logsMissingImport() async throws {
        let contentWithImport = """
        syntax = "proto3";
        import "missing/dep.proto";
        message Foo {}
        """
        let tempURL = try createTempProtoFile(content: contentWithImport, name: "dep_missing.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try? await sut.loadProto(url: tempURL, importPaths: [])

        XCTAssertEqual(mockLogger.errorMessages.count, 1)
        let missingImports = mockLogger.errorMessages[0].metadata["missing_imports"] ?? ""
        XCTAssertTrue(missingImports.contains("missing/dep.proto"))
    }

    func test_loadProto_whenSucceeds_doesNotLog() async throws {
        let content = "syntax = \"proto3\";\nservice S {}"
        let tempURL = try createTempProtoFile(content: content, name: "ok.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try await sut.loadProto(url: tempURL)

        XCTAssertTrue(mockLogger.errorMessages.isEmpty)
    }

    func test_loadProto_whenParsingFails_doesNotLeakFullPathInFileMetadata() async throws {
        let invalidContent = "not valid proto"
        let tempURL = try createTempProtoFile(content: invalidContent, name: "leaktest.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try? await sut.loadProto(url: tempURL)

        let fileMetadata = mockLogger.errorMessages[0].metadata["file"] ?? ""
        XCTAssertFalse(fileMetadata.contains("/"), "file metadata should be filename only, not a path")
    }

    func test_loadProto_withImportedMessageType_getMessageDescriptor_findsImportedType() async throws {
        // Given - two proto files where service.proto imports messages.proto
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("repo_test_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testDir) }

        let messageProtoContent = """
        syntax = "proto3";
        package imported;

        message ImportedRequest {
            string id = 1;
        }

        message ImportedResponse {
            string result = 1;
        }
        """
        let messageProtoURL = testDir.appendingPathComponent("messages.proto")
        try messageProtoContent.write(to: messageProtoURL, atomically: true, encoding: .utf8)

        let serviceProtoContent = """
        syntax = "proto3";
        package imported;

        import "messages.proto";

        service ImportedService {
            rpc DoWork (ImportedRequest) returns (ImportedResponse);
        }
        """
        let serviceProtoURL = testDir.appendingPathComponent("service.proto")
        try serviceProtoContent.write(to: serviceProtoURL, atomically: true, encoding: .utf8)

        // When - load service.proto with testDir as import path
        _ = try await sut.loadProto(url: serviceProtoURL, importPaths: [testDir.path])

        // Then - must find message type from imported file, not just from the main file
        let descriptor = try sut.getMessageDescriptor(forType: ".imported.ImportedRequest")
        XCTAssertEqual(descriptor.name, "ImportedRequest")
        XCTAssertEqual(descriptor.fields.count, 1)
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
            try sut.getMessageDescriptor(forType: ".mattis.dev.v1.regionspy.google.protobuf.Empty"))
        { error in
            guard case ProtoRepositoryError.messageTypeNotFound = error else {
                XCTFail("Expected messageTypeNotFound error")
                return
            }
        }
    }
}

// MARK: - Descriptor Deduplication Tests (TRMN-151)

extension FileSystemProtoRepositoryTests {
    func test_loadProto_whenSameFileLoadedTwice_updatesDescriptor() async throws {
        // Given - load v1 with one field
        let v1Content = """
        syntax = "proto3";
        package dedup;

        message DeduplicatedMessage {
            string field_one = 1;
        }

        service DeduplicatedService {
            rpc Get(DeduplicatedMessage) returns (DeduplicatedMessage);
        }
        """
        let tempURL = try createTempProtoFile(content: v1Content, name: "dedup_test.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try await sut.loadProto(url: tempURL)

        // When - overwrite the file with v2 (two fields) and load again
        let v2Content = """
        syntax = "proto3";
        package dedup;

        message DeduplicatedMessage {
            string field_one = 1;
            string field_two = 2;
        }

        service DeduplicatedService {
            rpc Get(DeduplicatedMessage) returns (DeduplicatedMessage);
        }
        """
        try v2Content.write(to: tempURL, atomically: true, encoding: .utf8)
        _ = try await sut.loadProto(url: tempURL)

        // Then - descriptor must reflect v2 (two fields, not one)
        let descriptor = try sut.getMessageDescriptor(forType: ".dedup.DeduplicatedMessage")
        XCTAssertEqual(descriptor.fields.count, 2, "Descriptor should be updated after re-loading the same file")
    }

    func test_loadProto_whenSameFileLoadedWithChangedMessage_newDescriptorIsUsed() async throws {
        // Given - initial schema: message has no fields
        let v1Content = """
        syntax = "proto3";
        package changed;

        message ChangedMessage {}

        service ChangedService {
            rpc Do(ChangedMessage) returns (ChangedMessage);
        }
        """
        let tempURL = try createTempProtoFile(content: v1Content, name: "changed_test.proto")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try await sut.loadProto(url: tempURL)

        let descriptorBefore = try sut.getMessageDescriptor(forType: ".changed.ChangedMessage")
        XCTAssertEqual(descriptorBefore.fields.count, 0)

        // When - schema evolves to add three new fields
        let v2Content = """
        syntax = "proto3";
        package changed;

        message ChangedMessage {
            string name = 1;
            int32 age = 2;
            bool active = 3;
        }

        service ChangedService {
            rpc Do(ChangedMessage) returns (ChangedMessage);
        }
        """
        try v2Content.write(to: tempURL, atomically: true, encoding: .utf8)
        _ = try await sut.loadProto(url: tempURL)

        // Then - getMessageDescriptor must return the new schema
        let descriptorAfter = try sut.getMessageDescriptor(forType: ".changed.ChangedMessage")
        XCTAssertEqual(descriptorAfter.fields.count, 3, "getMessageDescriptor must reflect the updated schema")
    }

    // MARK: - Dependency Paths Tests (TRMN-156)

    func test_loadProto_withNoDependencies_returnEmptyDependencyPaths() async throws {
        let content = """
        syntax = "proto3";
        message NoDepsMsg { string value = 1; }
        """
        let url = try createTempProtoFile(content: content, name: "no_deps.proto")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try await sut.loadProto(url: url)

        XCTAssertTrue(result.dependencyPaths.isEmpty)
    }

    func test_loadProto_withDependency_includesDependencyPath() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let subDir = tempDir.appendingPathComponent("dep_pkg_156")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: subDir) }

        let depContent = """
        syntax = "proto3";
        package dep;
        message DepMsg { string value = 1; }
        """
        let depURL = subDir.appendingPathComponent("dep.proto")
        try depContent.write(to: depURL, atomically: true, encoding: .utf8)

        let mainContent = """
        syntax = "proto3";
        import "dep_pkg_156/dep.proto";
        message Main { string value = 1; }
        """
        let mainURL = try createTempProtoFile(content: mainContent, name: "main_dep_156.proto")
        defer { try? FileManager.default.removeItem(at: mainURL) }

        let result = try await sut.loadProto(url: mainURL, importPaths: [tempDir.path])

        XCTAssertEqual(result.dependencyPaths.count, 1)
        XCTAssertEqual(result.dependencyPaths.first, depURL)
    }

    func test_loadProto_withWellKnownDependency_excludesWellKnownPath() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let wellKnownDir = tempDir.appendingPathComponent("wkt_bundle_156")
        let wktSubDir = wellKnownDir.appendingPathComponent("wkt")
        try? FileManager.default.createDirectory(at: wktSubDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: wellKnownDir) }

        let wktContent = """
        syntax = "proto3";
        package wkt;
        message WKTMsg { string value = 1; }
        """
        let wktURL = wktSubDir.appendingPathComponent("types.proto")
        try wktContent.write(to: wktURL, atomically: true, encoding: .utf8)

        sut = FileSystemProtoRepository(logger: mockLogger, wellKnownResourcePath: wellKnownDir.path)

        let mainContent = """
        syntax = "proto3";
        import "wkt/types.proto";
        message Main { string value = 1; }
        """
        let mainURL = try createTempProtoFile(content: mainContent, name: "main_wkt_156.proto")
        defer { try? FileManager.default.removeItem(at: mainURL) }

        let result = try await sut.loadProto(url: mainURL, importPaths: [wellKnownDir.path])

        XCTAssertTrue(result.dependencyPaths.isEmpty, "Paths under wellKnownResourcePath must be excluded")
    }

    func test_loadProto_whenDifferentFiles_bothDescriptorsStored() async throws {
        // Given - two independent proto files
        let fileAContent = """
        syntax = "proto3";
        package filea;

        message MessageA {
            string value = 1;
        }

        service ServiceA {
            rpc DoA(MessageA) returns (MessageA);
        }
        """
        let fileBContent = """
        syntax = "proto3";
        package fileb;

        message MessageB {
            int32 count = 1;
            bool flag = 2;
        }

        service ServiceB {
            rpc DoB(MessageB) returns (MessageB);
        }
        """
        let urlA = try createTempProtoFile(content: fileAContent, name: "file_a.proto")
        let urlB = try createTempProtoFile(content: fileBContent, name: "file_b.proto")
        defer {
            try? FileManager.default.removeItem(at: urlA)
            try? FileManager.default.removeItem(at: urlB)
        }

        // When - load both
        _ = try await sut.loadProto(url: urlA)
        _ = try await sut.loadProto(url: urlB)

        // Then - both descriptors must be accessible
        let descriptorA = try sut.getMessageDescriptor(forType: ".filea.MessageA")
        let descriptorB = try sut.getMessageDescriptor(forType: ".fileb.MessageB")

        XCTAssertEqual(descriptorA.fields.count, 1)
        XCTAssertEqual(descriptorB.fields.count, 2)
    }
}
