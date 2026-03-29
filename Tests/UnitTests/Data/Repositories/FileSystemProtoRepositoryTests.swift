import SwiftProtoReflect
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
        let protos = await sut.getLoadedProtos()

        // Then
        XCTAssertEqual(protos.count, 1)
        XCTAssertEqual(protos.first?.id, loaded.id)
    }

    func test_getLoadedProtos_withNoLoaded_returnsEmpty() async {
        // Given/When
        let protos = await sut.getLoadedProtos()

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

        let proto = try await sut.loadProto(url: tempURL)

        // When
        let descriptor = try await sut.getMessageDescriptor(forType: ".test.TestMessage", in: proto)

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

        let proto = try await sut.loadProto(url: tempURL)

        // When/Then
        do {
            _ = try await sut.getMessageDescriptor(forType: ".NonExistent", in: proto)
            XCTFail("Expected messageTypeNotFound error")
        } catch let error as ProtoRepositoryError {
            guard case .messageTypeNotFound = error else {
                XCTFail("Expected messageTypeNotFound error")
                return
            }
        }
    }

    func test_getMessageDescriptor_withNoLoadedProtos_throwsError() async throws {
        // Given - no protos loaded
        let scopeProto = ProtoFile(
            name: "orphan.proto",
            path: URL(fileURLWithPath: "/tmp/orphan.proto"),
            services: [])

        // When/Then
        do {
            _ = try await sut.getMessageDescriptor(forType: ".test.Message", in: scopeProto)
            XCTFail("Expected messageTypeNotFound error")
        } catch let error as ProtoRepositoryError {
            guard case .messageTypeNotFound = error else {
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

        let emptyProto = try await sut.loadProto(url: emptyProtoURL)

        // When
        let descriptor = try await sut.getMessageDescriptor(forType: ".google.protobuf.Empty", in: emptyProto)

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
        let loadedServiceProto = try await sut.loadProto(url: serviceProtoURL, importPaths: [testDir.path])

        // Then - must find message type from imported file, not just from the main file
        let descriptor = try await sut.getMessageDescriptor(
            forType: ".imported.ImportedRequest",
            in: loadedServiceProto)
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

        let emptyProto = try await sut.loadProto(url: emptyProtoURL)

        // When/Then - wrong package prefix should not resolve
        do {
            _ = try await sut.getMessageDescriptor(
                forType: ".mattis.dev.v1.regionspy.google.protobuf.Empty",
                in: emptyProto)
            XCTFail("Expected messageTypeNotFound error")
        } catch let error as ProtoRepositoryError {
            guard case .messageTypeNotFound = error else {
                XCTFail("Expected messageTypeNotFound error")
                return
            }
        }
    }

    func test_getMessageDescriptor_whenDuplicateUnqualifiedMessageName_scopedToProtoFile_returnsDistinctDescriptors()
        async throws
    {
        let contentA = """
        syntax = "proto3";

        message Dup {
            string field_a = 1;
        }

        service ServiceA {
            rpc Call(Dup) returns (Dup);
        }
        """
        let contentB = """
        syntax = "proto3";

        message Dup {
            int32 field_b = 1;
        }

        service ServiceB {
            rpc Call(Dup) returns (Dup);
        }
        """
        let urlA = try createTempProtoFile(content: contentA, name: "scope_a.proto")
        let urlB = try createTempProtoFile(content: contentB, name: "scope_b.proto")
        defer {
            try? FileManager.default.removeItem(at: urlA)
            try? FileManager.default.removeItem(at: urlB)
        }

        let protoA = try await sut.loadProto(url: urlA)
        let protoB = try await sut.loadProto(url: urlB)

        let descA = try await sut.getMessageDescriptor(forType: "Dup", in: protoA)
        let descB = try await sut.getMessageDescriptor(forType: "Dup", in: protoB)

        XCTAssertEqual(descA.fields.count, 1)
        XCTAssertTrue(descA.fields.values.contains { $0.name == "field_a" })
        XCTAssertEqual(descB.fields.count, 1)
        XCTAssertTrue(descB.fields.values.contains { $0.name == "field_b" })
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
        let protoAfterReload = try await sut.loadProto(url: tempURL)

        // Then - descriptor must reflect v2 (two fields, not one)
        let descriptor = try await sut.getMessageDescriptor(forType: ".dedup.DeduplicatedMessage", in: protoAfterReload)
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

        let protoBefore = try await sut.loadProto(url: tempURL)

        let descriptorBefore = try await sut.getMessageDescriptor(forType: ".changed.ChangedMessage", in: protoBefore)
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
        let protoAfter = try await sut.loadProto(url: tempURL)

        // Then - getMessageDescriptor must return the new schema
        let descriptorAfter = try await sut.getMessageDescriptor(forType: ".changed.ChangedMessage", in: protoAfter)
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

    // MARK: - Well-Known Type Scope Tests (regression: google/protobuf/* excluded from dependencyPaths but must remain resolvable)

    /// Regression: proto imports google.protobuf.Empty via well-known bundle path.
    /// dependencyPaths must be empty (no watching), yet getMessageDescriptor must succeed.
    func test_getMessageDescriptor_whenWellKnownEmptyImported_isResolvableDespiteExcludedDependencyPath()
        async throws
    {
        // Given - set up a fake "bundle resource" directory containing google/protobuf/empty.proto
        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wkt_bundle_\(UUID().uuidString)")
        let googleProtobufDir = bundleDir
            .appendingPathComponent("google")
            .appendingPathComponent("protobuf")
        try FileManager.default.createDirectory(at: googleProtobufDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleDir) }

        let emptyProtoContent = """
        syntax = "proto3";
        package google.protobuf;
        option java_package = "com.google.protobuf";
        option java_outer_classname = "EmptyProto";
        option java_multiple_files = true;
        option go_package = "google.golang.org/protobuf/types/known/emptypb";
        option objc_class_prefix = "GPB";
        option csharp_namespace = "Google.Protobuf.WellKnownTypes";
        message Empty {}
        """
        let emptyProtoURL = googleProtobufDir.appendingPathComponent("empty.proto")
        try emptyProtoContent.write(to: emptyProtoURL, atomically: true, encoding: .utf8)

        let userProtoContent = """
        syntax = "proto3";
        package example;
        import "google/protobuf/empty.proto";
        service HelloService {
            rpc Hello (google.protobuf.Empty) returns (google.protobuf.Empty);
        }
        """
        let userProtoURL = bundleDir.appendingPathComponent("hello.proto")
        try userProtoContent.write(to: userProtoURL, atomically: true, encoding: .utf8)

        sut = FileSystemProtoRepository(logger: mockLogger, wellKnownResourcePath: bundleDir.path)
        let protoFile = try await sut.loadProto(url: userProtoURL, importPaths: [bundleDir.path])

        // Well-known path must NOT appear in dependencyPaths (no file-watching)
        XCTAssertTrue(protoFile.dependencyPaths.isEmpty, "Well-known paths must be excluded from dependencyPaths")

        // When
        let descriptor = try await sut.getMessageDescriptor(forType: ".google.protobuf.Empty", in: protoFile)

        // Then - must resolve even though google/protobuf/empty.proto is not in dependencyPaths
        XCTAssertEqual(descriptor.name, "Empty")
        XCTAssertEqual(descriptor.fields.count, 0)
    }

    func test_getMessageDescriptor_whenWellKnownTimestampImported_isResolvableDespiteExcludedDependencyPath()
        async throws
    {
        // Given - fake bundle with google/protobuf/timestamp.proto
        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wkt_ts_bundle_\(UUID().uuidString)")
        let googleProtobufDir = bundleDir
            .appendingPathComponent("google")
            .appendingPathComponent("protobuf")
        try FileManager.default.createDirectory(at: googleProtobufDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleDir) }

        let timestampProtoContent = """
        syntax = "proto3";
        package google.protobuf;
        message Timestamp {
            int64 seconds = 1;
            int32 nanos = 2;
        }
        """
        let timestampProtoURL = googleProtobufDir.appendingPathComponent("timestamp.proto")
        try timestampProtoContent.write(to: timestampProtoURL, atomically: true, encoding: .utf8)

        let userProtoContent = """
        syntax = "proto3";
        package example;
        import "google/protobuf/timestamp.proto";
        message Event {
            google.protobuf.Timestamp created_at = 1;
        }
        service EventService {
            rpc GetEvent (Event) returns (Event);
        }
        """
        let userProtoURL = bundleDir.appendingPathComponent("event.proto")
        try userProtoContent.write(to: userProtoURL, atomically: true, encoding: .utf8)

        sut = FileSystemProtoRepository(logger: mockLogger, wellKnownResourcePath: bundleDir.path)
        let protoFile = try await sut.loadProto(url: userProtoURL, importPaths: [bundleDir.path])

        XCTAssertTrue(protoFile.dependencyPaths.isEmpty, "Well-known paths must be excluded from dependencyPaths")

        // When
        let descriptor = try await sut.getMessageDescriptor(forType: ".google.protobuf.Timestamp", in: protoFile)

        // Then
        XCTAssertEqual(descriptor.name, "Timestamp")
        XCTAssertEqual(descriptor.fields.count, 2)
    }

    func test_makeJSONTypeRegistry_whenWellKnownTimestampImported_includesGoogleProtobufTimestamp() async throws {
        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wkt_ts_registry_\(UUID().uuidString)")
        let googleProtobufDir = bundleDir
            .appendingPathComponent("google")
            .appendingPathComponent("protobuf")
        try FileManager.default.createDirectory(at: googleProtobufDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleDir) }

        let timestampProtoContent = """
        syntax = "proto3";
        package google.protobuf;
        message Timestamp {
            int64 seconds = 1;
            int32 nanos = 2;
        }
        """
        try timestampProtoContent.write(
            to: googleProtobufDir.appendingPathComponent("timestamp.proto"),
            atomically: true,
            encoding: .utf8)

        let userProtoContent = """
        syntax = "proto3";
        package example;
        import "google/protobuf/timestamp.proto";
        message Event {
            google.protobuf.Timestamp created_at = 1;
        }
        service EventService {
            rpc GetEvent (Event) returns (Event);
        }
        """
        let userProtoURL = bundleDir.appendingPathComponent("event.proto")
        try userProtoContent.write(to: userProtoURL, atomically: true, encoding: .utf8)

        sut = FileSystemProtoRepository(logger: mockLogger, wellKnownResourcePath: bundleDir.path)
        let protoFile = try await sut.loadProto(url: userProtoURL, importPaths: [bundleDir.path])

        let registry = try await sut.makeJSONTypeRegistry(for: protoFile)

        XCTAssertTrue(
            registry.hasMessage(named: WellKnownTypeNames.timestamp),
            "JSON nested WKT fields require google.protobuf.Timestamp in TypeRegistry")
    }

    func test_getMessageDescriptor_whenWellKnownTypeImported_userTypeAlsoResolvable() async throws {
        // Given - user proto imports well-known type AND defines its own message
        let bundleDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("wkt_mix_bundle_\(UUID().uuidString)")
        let googleProtobufDir = bundleDir
            .appendingPathComponent("google")
            .appendingPathComponent("protobuf")
        try FileManager.default.createDirectory(at: googleProtobufDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundleDir) }

        let emptyProtoContent = """
        syntax = "proto3";
        package google.protobuf;
        message Empty {}
        """
        try emptyProtoContent.write(
            to: googleProtobufDir.appendingPathComponent("empty.proto"),
            atomically: true, encoding: .utf8)

        let userProtoContent = """
        syntax = "proto3";
        package myapp;
        import "google/protobuf/empty.proto";
        message CreateRequest {
            string name = 1;
        }
        service MyService {
            rpc Create (CreateRequest) returns (google.protobuf.Empty);
        }
        """
        let userProtoURL = bundleDir.appendingPathComponent("myservice.proto")
        try userProtoContent.write(to: userProtoURL, atomically: true, encoding: .utf8)

        sut = FileSystemProtoRepository(logger: mockLogger, wellKnownResourcePath: bundleDir.path)
        let protoFile = try await sut.loadProto(url: userProtoURL, importPaths: [bundleDir.path])

        // When - resolve both the user type and the well-known type
        let userDescriptor = try await sut.getMessageDescriptor(forType: ".myapp.CreateRequest", in: protoFile)
        let wktDescriptor = try await sut.getMessageDescriptor(forType: ".google.protobuf.Empty", in: protoFile)

        // Then
        XCTAssertEqual(userDescriptor.name, "CreateRequest")
        XCTAssertEqual(userDescriptor.fields.count, 1)
        XCTAssertEqual(wktDescriptor.name, "Empty")
        XCTAssertEqual(wktDescriptor.fields.count, 0)
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
        let protoA = try await sut.loadProto(url: urlA)
        let protoB = try await sut.loadProto(url: urlB)

        // Then - both descriptors must be accessible
        let descriptorA = try await sut.getMessageDescriptor(forType: ".filea.MessageA", in: protoA)
        let descriptorB = try await sut.getMessageDescriptor(forType: ".fileb.MessageB", in: protoB)

        XCTAssertEqual(descriptorA.fields.count, 1)
        XCTAssertEqual(descriptorB.fields.count, 2)
    }
}
