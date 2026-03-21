import Foundation
import os
import XCTest
@testable import TrueRPCMini

/// Tests for GenerateMockDataUseCase - generating mock JSON for gRPC requests
final class GenerateMockDataUseCaseTests: XCTestCase {
    var sut: GenerateMockDataUseCase!
    fileprivate var mockGenerator: SpyMockDataGenerator!

    override func setUp() {
        super.setUp()
        mockGenerator = SpyMockDataGenerator()
        sut = GenerateMockDataUseCase(mockDataGenerator: mockGenerator)
    }

    override func tearDown() {
        sut = nil
        mockGenerator = nil
        super.tearDown()
    }

    // MARK: - Happy Path

    func test_execute_generatesMockJSON() async throws {
        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false)
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [])

        let mockJSON = try await sut.execute(method: method, protoFile: protoFile)

        XCTAssertFalse(mockJSON.isEmpty)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: XCTUnwrap(mockJSON.data(using: .utf8))))
    }

    func test_execute_generatesNonEmptyJSON() async throws {
        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false)
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [])

        let mockJSON = try await sut.execute(method: method, protoFile: protoFile)

        XCTAssertTrue(mockJSON.contains("{"))
        XCTAssertTrue(mockJSON.contains("}"))
    }

    func test_execute_passesProtoFileThroughToGenerator() async throws {
        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false)
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [])

        _ = try await sut.execute(method: method, protoFile: protoFile)

        XCTAssertEqual(mockGenerator.lastProtoFile, protoFile)
    }

    func test_execute_passesInputTypeThroughToGenerator() async throws {
        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false)
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [])

        _ = try await sut.execute(method: method, protoFile: protoFile)

        XCTAssertEqual(mockGenerator.lastMessageType, "GetUserRequest")
    }

    func test_execute_whenGeneratorThrows_propagatesError() async {
        mockGenerator.shouldThrow = true

        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false)
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [])

        do {
            _ = try await sut.execute(method: method, protoFile: protoFile)
            XCTFail("Expected error to be thrown")
        } catch is SpyMockDataGenerator.GenerationFailure {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Spy

private final class SpyMockDataGenerator: MockDataGeneratorProtocol, Sendable {
    enum GenerationFailure: Error {
        case stub
    }

    private struct State {
        var lastMessageType: String?
        var lastProtoFile: ProtoFile?
        var shouldThrow: Bool = false
    }

    private let storage = OSAllocatedUnfairLock(initialState: State())

    var shouldThrow: Bool {
        get { storage.withLock { $0.shouldThrow } }
        set { storage.withLock { $0.shouldThrow = newValue } }
    }

    var lastMessageType: String? {
        storage.withLock { $0.lastMessageType }
    }

    var lastProtoFile: ProtoFile? {
        storage.withLock { $0.lastProtoFile }
    }

    func generate(for messageType: String, in protoFile: ProtoFile) throws -> String {
        storage.withLock {
            $0.lastMessageType = messageType
            $0.lastProtoFile = protoFile
        }
        if storage.withLock({ $0.shouldThrow }) {
            throw GenerationFailure.stub
        }
        return "{}"
    }
}
