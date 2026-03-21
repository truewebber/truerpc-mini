import XCTest
@testable import TrueRPCMini

/// Tests for MockDataGenerator - generating mock JSON from proto message types
final class MockDataGeneratorTests: XCTestCase {
    var sut: MockDataGenerator!

    override func setUp() {
        super.setUp()
        sut = MockDataGenerator()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Happy Path

    func test_generate_returnsValidJSON() async throws {
        let messageType = "TestMessage"
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [])

        let json = try await sut.generate(for: messageType, in: protoFile)

        XCTAssertFalse(json.isEmpty)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: XCTUnwrap(json.data(using: .utf8))))
    }

    func test_generate_returnsJSONObject() async throws {
        let messageType = "TestMessage"
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [])

        let json = try await sut.generate(for: messageType, in: protoFile)

        XCTAssertTrue(json.contains("{"))
        XCTAssertTrue(json.contains("}"))
    }

    func test_generate_multipleCalls_returnsConsistentFormat() async throws {
        let messageType = "TestMessage"
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [])

        let json1 = try await sut.generate(for: messageType, in: protoFile)
        let json2 = try await sut.generate(for: messageType, in: protoFile)

        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: XCTUnwrap(json1.data(using: .utf8))))
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: XCTUnwrap(json2.data(using: .utf8))))
    }
}
