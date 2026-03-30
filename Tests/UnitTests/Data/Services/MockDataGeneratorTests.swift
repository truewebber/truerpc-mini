import Foundation
import SwiftProtoReflect
import XCTest
@testable import TrueRPCMini

/// Tests for MockDataGenerator — mock JSON from proto message types
final class MockDataGeneratorTests: XCTestCase {
    private var protoFile: ProtoFile!

    override func setUp() {
        super.setUp()
        protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [])
    }

    override func tearDown() {
        protoFile = nil
        super.tearDown()
    }

    func test_generate_forScalarMessage_returnsValidJson() async throws {
        let file = FileDescriptor(name: "t.proto", package: "scalar")
        var message = MessageDescriptor(name: "Scalars", parent: file)
        message.addField(FieldDescriptor(name: "d", number: 1, type: .double))
        message.addField(FieldDescriptor(name: "f", number: 2, type: .float))
        message.addField(FieldDescriptor(name: "i32", number: 3, type: .int32))
        message.addField(FieldDescriptor(name: "i64", number: 4, type: .int64))
        message.addField(FieldDescriptor(name: "u32", number: 5, type: .uint32))
        message.addField(FieldDescriptor(name: "u64", number: 6, type: .uint64))
        message.addField(FieldDescriptor(name: "b", number: 7, type: .bool))
        message.addField(FieldDescriptor(name: "s", number: 8, type: .string))
        message.addField(FieldDescriptor(name: "raw", number: 9, type: .bytes))

        let repo = StubProtoRepository(descriptors: ["scalar.Scalars": message], defaultDescriptor: message)
        let sut = MockDataGenerator(protoRepository: repo)

        let json = try await sut.generate(for: "scalar.Scalars", in: protoFile)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(obj.keys.count, 9)
        XCTAssertNotNil(obj["d"] as? Double)
        XCTAssertNotNil(obj["f"] as? Double)
        XCTAssertNotNil(obj["i32"] as? Int)
        XCTAssertNotNil(obj["i64"] as? String)
        XCTAssertNotNil(obj["u32"] as? Int)
        XCTAssertNotNil(obj["u64"] as? String)
        XCTAssertNotNil(obj["b"] as? Bool)
        XCTAssertEqual(obj["s"] as? String, "Lorem ipsum dolor sit amet")
        XCTAssertNotNil(obj["raw"] as? String)
    }

    func test_generate_forRepeatedField_returnsArrayWithOneElement() async throws {
        let file = FileDescriptor(name: "t.proto", package: "rep")
        var message = MessageDescriptor(name: "R", parent: file)
        message.addField(FieldDescriptor(name: "items", number: 1, type: .string, isRepeated: true))

        let repo = StubProtoRepository(descriptors: ["rep.R": message])
        let sut = MockDataGenerator(protoRepository: repo)

        let json = try await sut.generate(for: "rep.R", in: protoFile)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let items = try XCTUnwrap(obj["items"] as? [Any])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0] as? String, "Lorem ipsum dolor sit amet")
    }

    func test_generate_forNestedEnumField_skipsZeroIndex() async throws {
        let file = FileDescriptor(name: "t.proto", package: "en")
        var message = MessageDescriptor(name: "Msg", parent: file)
        var enumDesc = EnumDescriptor(name: "E", parent: message)
        enumDesc.addValue(EnumDescriptor.EnumValue(name: "UNKNOWN", number: 0))
        enumDesc.addValue(EnumDescriptor.EnumValue(name: "ACTIVE", number: 1))
        message.addNestedEnum(enumDesc)
        message.addField(FieldDescriptor(name: "status", number: 1, type: .enum, typeName: message.fullName + ".E"))

        let repo = StubProtoRepository(descriptors: ["en.Msg": message])
        let sut = MockDataGenerator(protoRepository: repo)

        let json = try await sut.generate(for: "en.Msg", in: protoFile)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["status"] as? Int, 1)
    }

    func test_generate_forTopLevelEnumField_returnsNonZeroValue() async throws {
        // top-level enum (not nested in any message) — the original bug case
        let file = FileDescriptor(name: "t.proto", package: "pkg")
        var topLevelEnum = EnumDescriptor(name: "IntervalGroupType", parent: file)
        topLevelEnum.addValue(EnumDescriptor.EnumValue(name: "INTERVAL_GROUP_TYPE_UNSPECIFIED", number: 0))
        topLevelEnum.addValue(EnumDescriptor.EnumValue(name: "INTERVAL_GROUP_TYPE_DAYS", number: 1))
        topLevelEnum.addValue(EnumDescriptor.EnumValue(name: "INTERVAL_GROUP_TYPE_WEEKS", number: 2))

        var message = MessageDescriptor(name: "GetGroupedAdsRequest", parent: file)
        message.addField(FieldDescriptor(
            name: "interval_group",
            number: 1,
            type: .enum,
            typeName: "pkg.IntervalGroupType"))

        let repo = StubProtoRepository(
            descriptors: ["pkg.GetGroupedAdsRequest": message],
            enumDescriptors: ["pkg.IntervalGroupType": topLevelEnum])
        let sut = MockDataGenerator(protoRepository: repo)

        let json = try await sut.generate(for: "pkg.GetGroupedAdsRequest", in: protoFile)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let value = try XCTUnwrap(obj["interval_group"] as? Int)
        XCTAssertTrue(value == 1 || value == 2, "Expected non-zero enum value, got \(value)")
    }

    func test_generate_forOneOfField_fillsExactlyOneOption() async throws {
        let file = FileDescriptor(name: "t.proto", package: "one")
        var message = MessageDescriptor(name: "O", parent: file)
        message.addOneofDecl(OneofDescriptor(name: "pick", index: 0))
        message.addField(FieldDescriptor(name: "a_str", number: 1, type: .string, oneofIndex: 0))
        message.addField(FieldDescriptor(name: "b_int", number: 2, type: .int32, oneofIndex: 0))

        let repo = StubProtoRepository(descriptors: ["one.O": message])
        let sut = MockDataGenerator(protoRepository: repo)

        let json = try await sut.generate(for: "one.O", in: protoFile)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        let hasA = obj["a_str"] != nil
        let hasB = obj["b_int"] != nil
        XCTAssertTrue(hasA != hasB, "Expected exactly one oneof branch set, got \(obj.keys.sorted())")
    }

    func test_generate_withCircularReference_capsDepthAtOne() async throws {
        let file = FileDescriptor(name: "c.proto", package: "pkg")
        var message = MessageDescriptor(name: "A", parent: file)
        message.addField(FieldDescriptor(name: "child", number: 1, type: .message, typeName: "pkg.A"))

        let repo = StubProtoRepository(descriptors: ["pkg.A": message])
        let sut = MockDataGenerator(protoRepository: repo)

        let json = try await sut.generate(for: "pkg.A", in: protoFile)
        let data = try XCTUnwrap(json.data(using: .utf8))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let child = try XCTUnwrap(obj["child"] as? [String: Any])
        XCTAssertTrue(child.isEmpty)
    }

    func test_generate_forTimestampWKT_returnsRfc3339String() async throws {
        let file = FileDescriptor(name: "ts.proto", package: "google.protobuf")
        let message = MessageDescriptor(name: "Timestamp", parent: file)

        let repo = StubProtoRepository(descriptors: [WellKnownTypeNames.timestamp: message])
        let sut = MockDataGenerator(protoRepository: repo)

        let json = try await sut.generate(for: WellKnownTypeNames.timestamp, in: protoFile)
        XCTAssertTrue(json.hasPrefix("\"") && json.hasSuffix("\""))
        let inner = String(json.dropFirst().dropLast())
        XCTAssertEqual(inner, "2006-01-02T15:04:05Z")
    }

    func test_generate_forDurationWKT_returnsCorrectFormat() async throws {
        let file = FileDescriptor(name: "dur.proto", package: "google.protobuf")
        let message = MessageDescriptor(name: "Duration", parent: file)

        let repo = StubProtoRepository(descriptors: [WellKnownTypeNames.duration: message])
        let sut = MockDataGenerator(protoRepository: repo)

        let json = try await sut.generate(for: WellKnownTypeNames.duration, in: protoFile)
        XCTAssertTrue(json.hasPrefix("\"") && json.hasSuffix("\""))
        let inner = String(json.dropFirst().dropLast())
        let pattern = #"^[0-9]+(\.[0-9]+)?s$"#
        let range = NSRange(inner.startIndex..., in: inner)
        let regex = try NSRegularExpression(pattern: pattern)
        XCTAssertNotNil(regex.firstMatch(in: inner, options: [], range: range))
    }

    func test_generate_returnsValidJSON() async throws {
        let repo = StubProtoRepository()
        let sut = MockDataGenerator(protoRepository: repo)

        let json = try await sut.generate(for: "stub.Empty", in: protoFile)

        XCTAssertFalse(json.isEmpty)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: XCTUnwrap(json.data(using: .utf8))))
    }

    func test_generate_returnsJSONObject() async throws {
        let repo = StubProtoRepository()
        let sut = MockDataGenerator(protoRepository: repo)

        let json = try await sut.generate(for: "stub.Empty", in: protoFile)

        XCTAssertTrue(json.contains("{"))
        XCTAssertTrue(json.contains("}"))
    }

    func test_generate_multipleCalls_returnsConsistentFormat() async throws {
        let repo = StubProtoRepository()
        let sut = MockDataGenerator(protoRepository: repo)

        let json1 = try await sut.generate(for: "stub.Empty", in: protoFile)
        let json2 = try await sut.generate(for: "stub.Empty", in: protoFile)

        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: XCTUnwrap(json1.data(using: .utf8))))
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: XCTUnwrap(json2.data(using: .utf8))))
    }
}
