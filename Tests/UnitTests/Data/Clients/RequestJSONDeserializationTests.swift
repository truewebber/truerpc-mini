import SwiftProtoReflect
import XCTest
@testable import TrueRPCMini

// swiftlint:disable file_length type_body_length

/// Full-chain tests for `GrpcSwiftDynamicClient.parseJSON(_:using:typeRegistry:)`.
///
/// Input: JSON `String` + `MessageDescriptor` + `TypeRegistry`
/// Output: `DynamicMessage` compared via `Equatable` against a golden expected message.
///
/// Covers test plan sections §4–§16.
final class RequestJSONDeserializationTests: XCTestCase {
    private var sut: GrpcSwiftDynamicClient!

    override func setUp() {
        super.setUp()
        let repo = StubProtoRepository()
        sut = GrpcSwiftDynamicClient(protoRepository: repo, logger: MockAppLogger())
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private let file = FileDescriptor(name: "test.proto", package: "test")

    private func parse(_ json: String, descriptor: MessageDescriptor, registry: TypeRegistry) throws -> DynamicMessage {
        try sut.parseJSON(json, using: descriptor, typeRegistry: registry)
    }

    private func registry(with descriptors: [MessageDescriptor] = []) -> TypeRegistry {
        let reg = TypeRegistry()
        let pool = DescriptorPool(includeBuiltinDescriptors: true)
        for name in pool.allMessageTypeNames() {
            if let desc = pool.findMessageDescriptor(named: name) {
                try? reg.registerMessage(desc)
            }
        }
        for desc in descriptors {
            try? reg.registerMessage(desc)
        }
        return reg
    }

    // MARK: - §4 Scalars

    func test_S1_double_fromNumber() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .double))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": 1.25}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(1.25, forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S3_int32_fromNumber() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .int32))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": 42}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(Int32(42), forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S4_int64_fromNumber() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .int64))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": 100}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(Int64(100), forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S5_uint32_fromNumber() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .uint32))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": 42}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(UInt32(42), forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S6_uint64_fromNumber() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .uint64))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": 100}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(UInt64(100), forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S7_sint32_fromNumber() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .sint32))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": -42}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(Int32(-42), forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S8_sint64_fromNumber() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .sint64))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": -100}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(Int64(-100), forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S9_fixed32_fromNumber() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .fixed32))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": 42}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(UInt32(42), forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S10_sfixed32_fromNumber() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .sfixed32))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": -42}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(Int32(-42), forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S11_bool_true() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .bool))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": true}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(true, forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S11_bool_false() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .bool))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": false}"#, descriptor: desc, registry: reg)

        let val = try result.get(forField: "val") as? Bool
        XCTAssertEqual(val, false)
    }

    func test_S12_string() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .string))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": "hello"}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set("hello", forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S12_string_empty() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .string))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": ""}"#, descriptor: desc, registry: reg)

        let val = try result.get(forField: "val") as? String
        XCTAssertEqual(val, "")
    }

    func test_S12_string_unicode() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .string))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": "Привет 🌍"}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set("Привет 🌍", forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S13_bytes_base64() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .bytes))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": "SGVsbG8="}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(Data("Hello".utf8), forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_S2_float_fromNumber() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "val", number: 1, type: .float))
        let reg = registry(with: [desc])

        let result = try parse(#"{"val": 1.5}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(Float(1.5), forField: "val")
        XCTAssertEqual(result, expected)
    }

    func test_scalars_multiField() throws {
        var desc = MessageDescriptor(name: "AllScalars", parent: file)
        desc.addField(FieldDescriptor(name: "d", number: 1, type: .double))
        desc.addField(FieldDescriptor(name: "f", number: 2, type: .float))
        desc.addField(FieldDescriptor(name: "i32", number: 3, type: .int32))
        desc.addField(FieldDescriptor(name: "i64", number: 4, type: .int64))
        desc.addField(FieldDescriptor(name: "b", number: 5, type: .bool))
        desc.addField(FieldDescriptor(name: "s", number: 6, type: .string))
        let reg = registry(with: [desc])

        let json = #"{"d": 1.25, "f": 2.5, "i32": 42, "i64": 100, "b": true, "s": "test"}"#
        let result = try parse(json, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(1.25, forField: "d")
        try expected.set(Float(2.5), forField: "f")
        try expected.set(Int32(42), forField: "i32")
        try expected.set(Int64(100), forField: "i64")
        try expected.set(true, forField: "b")
        try expected.set("test", forField: "s")
        XCTAssertEqual(result, expected)
    }

    // MARK: - §5 Enums

    func test_E1_enum_numericValue() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "status", number: 1, type: .enum, typeName: "test.Status"))
        var enumDesc = EnumDescriptor(name: "Status", parent: file)
        enumDesc.addValue(EnumDescriptor.EnumValue(name: "UNKNOWN", number: 0))
        enumDesc.addValue(EnumDescriptor.EnumValue(name: "ACTIVE", number: 1))
        desc.addNestedEnum(enumDesc)
        let reg = registry(with: [desc])

        let result = try parse(#"{"status": 1}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(Int32(1), forField: "status")
        XCTAssertEqual(result, expected)
    }

    func test_E3_enum_unknownNumericValue() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "status", number: 1, type: .enum, typeName: "test.Status"))
        var enumDesc = EnumDescriptor(name: "Status", parent: file)
        enumDesc.addValue(EnumDescriptor.EnumValue(name: "UNKNOWN", number: 0))
        desc.addNestedEnum(enumDesc)
        let reg = registry(with: [desc])

        let result = try parse(#"{"status": 999}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(Int32(999), forField: "status")
        XCTAssertEqual(result, expected)
    }

    // MARK: - §6 json_name

    func test_JN1_camelCaseKey_matchesJsonName() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "created_at", number: 1, type: .string, jsonName: "createdAt"))
        let reg = registry(with: [desc])

        let result = try parse(#"{"createdAt": "2024-01-01"}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set("2024-01-01", forField: "created_at")
        XCTAssertEqual(result, expected)
    }

    func test_JN2_snakeCaseKey_matchesFieldName() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "created_at", number: 1, type: .string, jsonName: "createdAt"))
        let reg = registry(with: [desc])

        let result = try parse(#"{"created_at": "2024-01-01"}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set("2024-01-01", forField: "created_at")
        XCTAssertEqual(result, expected)
    }

    func test_JN3_wrongCase_ignoredAsUnknown() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "created_at", number: 1, type: .string, jsonName: "createdAt"))
        let reg = registry(with: [desc])

        let result = try parse(#"{"CreatedAt": "2024-01-01"}"#, descriptor: desc, registry: reg)

        let expected = MessageFactory().createMessage(from: desc)
        XCTAssertEqual(result, expected)
    }

    // MARK: - §8 Nested Messages

    func test_N1_singleNested_allFieldsSet() throws {
        var subDesc = MessageDescriptor(name: "Sub", parent: file)
        subDesc.addField(FieldDescriptor(name: "a", number: 1, type: .int32))
        subDesc.addField(FieldDescriptor(name: "b", number: 2, type: .string))

        var rootDesc = MessageDescriptor(name: "Root", parent: file)
        rootDesc.addField(FieldDescriptor(name: "sub", number: 1, type: .message, typeName: "test.Sub"))
        let reg = registry(with: [subDesc, rootDesc])

        let result = try parse(#"{"sub": {"a": 1, "b": "x"}}"#, descriptor: rootDesc, registry: reg)

        var subExpected = MessageFactory().createMessage(from: subDesc)
        try subExpected.set(Int32(1), forField: "a")
        try subExpected.set("x", forField: "b")
        var expected = MessageFactory().createMessage(from: rootDesc)
        try expected.set(subExpected, forField: "sub")
        XCTAssertEqual(result, expected)
    }

    func test_N2_nestedOmitted() throws {
        var subDesc = MessageDescriptor(name: "Sub", parent: file)
        subDesc.addField(FieldDescriptor(name: "a", number: 1, type: .int32))

        var rootDesc = MessageDescriptor(name: "Root", parent: file)
        rootDesc.addField(FieldDescriptor(name: "sub", number: 1, type: .message, typeName: "test.Sub"))
        rootDesc.addField(FieldDescriptor(name: "name", number: 2, type: .string))
        let reg = registry(with: [subDesc, rootDesc])

        let result = try parse(#"{"name": "test"}"#, descriptor: rootDesc, registry: reg)

        var expected = MessageFactory().createMessage(from: rootDesc)
        try expected.set("test", forField: "name")
        XCTAssertEqual(result, expected)
    }

    func test_N3_nestedEmptyObject() throws {
        var subDesc = MessageDescriptor(name: "Sub", parent: file)
        subDesc.addField(FieldDescriptor(name: "a", number: 1, type: .int32))

        var rootDesc = MessageDescriptor(name: "Root", parent: file)
        rootDesc.addField(FieldDescriptor(name: "sub", number: 1, type: .message, typeName: "test.Sub"))
        let reg = registry(with: [subDesc, rootDesc])

        let result = try parse(#"{"sub": {}}"#, descriptor: rootDesc, registry: reg)

        let subExpected = MessageFactory().createMessage(from: subDesc)
        var expected = MessageFactory().createMessage(from: rootDesc)
        try expected.set(subExpected, forField: "sub")
        XCTAssertEqual(result, expected)
    }

    func test_N4_deepNesting_threeLevels() throws {
        var cDesc = MessageDescriptor(name: "C", parent: file)
        cDesc.addField(FieldDescriptor(name: "val", number: 1, type: .string))

        var bDesc = MessageDescriptor(name: "B", parent: file)
        bDesc.addField(FieldDescriptor(name: "c", number: 1, type: .message, typeName: "test.C"))

        var aDesc = MessageDescriptor(name: "A", parent: file)
        aDesc.addField(FieldDescriptor(name: "b", number: 1, type: .message, typeName: "test.B"))
        let reg = registry(with: [cDesc, bDesc, aDesc])

        let result = try parse(#"{"b": {"c": {"val": "deep"}}}"#, descriptor: aDesc, registry: reg)

        var cExpected = MessageFactory().createMessage(from: cDesc)
        try cExpected.set("deep", forField: "val")
        var bExpected = MessageFactory().createMessage(from: bDesc)
        try bExpected.set(cExpected, forField: "c")
        var expected = MessageFactory().createMessage(from: aDesc)
        try expected.set(bExpected, forField: "b")
        XCTAssertEqual(result, expected)
    }

    // MARK: - §9 Repeated

    func test_R1_repeatedScalar_empty() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "tags", number: 1, type: .string, isRepeated: true))
        let reg = registry(with: [desc])

        let result = try parse(#"{"tags": []}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set([String]() as [Any], forField: "tags")
        XCTAssertEqual(result, expected)
    }

    func test_R2_repeatedScalar_singleElement() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "nums", number: 1, type: .int32, isRepeated: true))
        let reg = registry(with: [desc])

        let result = try parse(#"{"nums": [42]}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set([Int32(42)] as [Any], forField: "nums")
        XCTAssertEqual(result, expected)
    }

    func test_R3_repeatedScalar_multipleElements() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "nums", number: 1, type: .int32, isRepeated: true))
        let reg = registry(with: [desc])

        let result = try parse(#"{"nums": [1, 2, 3]}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set([Int32(1), Int32(2), Int32(3)] as [Any], forField: "nums")
        XCTAssertEqual(result, expected)
    }

    func test_R4_repeatedMessage() throws {
        var itemDesc = MessageDescriptor(name: "Item", parent: file)
        itemDesc.addField(FieldDescriptor(name: "a", number: 1, type: .int32))

        var rootDesc = MessageDescriptor(name: "Root", parent: file)
        rootDesc.addField(
            FieldDescriptor(name: "items", number: 1, type: .message, typeName: "test.Item", isRepeated: true))
        let reg = registry(with: [itemDesc, rootDesc])

        let result = try parse(#"{"items": [{"a": 1}, {"a": 2}]}"#, descriptor: rootDesc, registry: reg)

        var item1 = MessageFactory().createMessage(from: itemDesc)
        try item1.set(Int32(1), forField: "a")
        var item2 = MessageFactory().createMessage(from: itemDesc)
        try item2.set(Int32(2), forField: "a")
        var expected = MessageFactory().createMessage(from: rootDesc)
        try expected.set([item1, item2] as [Any], forField: "items")
        XCTAssertEqual(result, expected)
    }

    func test_R6_emptyArray_equivalentToOmitted() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "tags", number: 1, type: .string, isRepeated: true))
        desc.addField(FieldDescriptor(name: "name", number: 2, type: .string))
        let reg = registry(with: [desc])

        let withEmpty = try parse(#"{"tags": [], "name": "a"}"#, descriptor: desc, registry: reg)
        let withOmitted = try parse(#"{"name": "a"}"#, descriptor: desc, registry: reg)

        let tagsEmpty = try (withEmpty.get(forField: "tags") as? [Any]) ?? []
        let tagsOmitted = try (withOmitted.get(forField: "tags") as? [Any]) ?? []
        XCTAssertEqual(tagsEmpty.count, 0)
        XCTAssertEqual(tagsOmitted.count, 0)
        XCTAssertEqual(try withEmpty.get(forField: "name") as? String, "a")
        XCTAssertEqual(try withOmitted.get(forField: "name") as? String, "a")
    }

    func test_R7_wrongType_objectInsteadOfArray() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "tags", number: 1, type: .string, isRepeated: true))
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"{"tags": {}}"#, descriptor: desc, registry: reg))
    }

    // MARK: - §10 Maps

    func test_M1_mapStringString() throws {
        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(name: "value", number: 2, type: .string))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "labels", number: 1, type: .message,
            typeName: "test.Msg.LabelsEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = registry(with: [desc])

        let result = try parse(#"{"labels": {"a": "x", "b": "y"}}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(["a": "x", "b": "y"] as [AnyHashable: Any], forField: "labels")
        XCTAssertEqual(result, expected)
    }

    func test_M2_mapStringInt32() throws {
        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(name: "value", number: 2, type: .int32))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "counts", number: 1, type: .message,
            typeName: "test.Msg.CountsEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = registry(with: [desc])

        let result = try parse(#"{"counts": {"k": 42}}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set(["k": Int32(42)] as [AnyHashable: Any], forField: "counts")
        XCTAssertEqual(result, expected)
    }

    func test_M7_mapStringSubMessage() throws {
        var subDesc = MessageDescriptor(name: "Sub", parent: file)
        subDesc.addField(FieldDescriptor(name: "val", number: 1, type: .string))

        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(name: "value", number: 2, type: .message, typeName: "test.Sub"))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "subs", number: 1, type: .message,
            typeName: "test.Msg.SubsEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = registry(with: [subDesc, desc])

        let result = try parse(#"{"subs": {"k": {"val": "hello"}}}"#, descriptor: desc, registry: reg)

        let mapVal = try XCTUnwrap(try result.get(forField: "subs") as? [AnyHashable: Any])
        let sub = try XCTUnwrap(mapVal["k"] as? DynamicMessage)
        XCTAssertEqual(try sub.get(forField: "val") as? String, "hello")
    }

    func test_M12_emptyMap() throws {
        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(name: "value", number: 2, type: .string))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "labels", number: 1, type: .message,
            typeName: "test.Msg.LabelsEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = registry(with: [desc])

        let result = try parse(#"{"labels": {}}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set([AnyHashable: Any](), forField: "labels")
        XCTAssertEqual(result, expected)
    }

    // MARK: - §11.1 WKT Timestamp

    func test_TS1_timestamp_rfc3339_utc() throws {
        let pool = DescriptorPool(includeBuiltinDescriptors: true)
        let tsDesc = try XCTUnwrap(pool.findMessageDescriptor(named: WellKnownTypeNames.timestamp))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = registry(with: [desc])

        let result = try parse(#"{"ts": "2024-01-01T00:00:00Z"}"#, descriptor: desc, registry: reg)

        let ts = try XCTUnwrap(try result.get(forField: "ts") as? DynamicMessage)
        XCTAssertEqual(try ts.get(forField: "seconds") as? Int64, 1_704_067_200)
        XCTAssertEqual(try ts.get(forField: "nanos") as? Int32, 0)

        _ = tsDesc // keep reference
    }

    func test_TS4_timestamp_epoch() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = registry(with: [desc])

        let result = try parse(#"{"ts": "1970-01-01T00:00:00Z"}"#, descriptor: desc, registry: reg)

        let ts = try XCTUnwrap(try result.get(forField: "ts") as? DynamicMessage)
        XCTAssertEqual(try ts.get(forField: "seconds") as? Int64, 0)
        XCTAssertEqual(try ts.get(forField: "nanos") as? Int32, 0)
    }

    func test_TS6_timestamp_objectForm_passThrough() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = registry(with: [desc])

        let result = try parse(#"{"ts": {"seconds": 100, "nanos": 0}}"#, descriptor: desc, registry: reg)

        let ts = try XCTUnwrap(try result.get(forField: "ts") as? DynamicMessage)
        XCTAssertEqual(try ts.get(forField: "seconds") as? Int64, 100)
        XCTAssertEqual(try ts.get(forField: "nanos") as? Int32, 0)
    }

    func test_TS8_timestamp_repeated() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "times", number: 1, type: .message,
            typeName: WellKnownTypeNames.timestamp, isRepeated: true))
        let reg = registry(with: [desc])

        let result = try parse(
            #"{"times": ["1970-01-01T00:00:00Z", "2000-01-01T00:00:00Z"]}"#,
            descriptor: desc, registry: reg)

        let times = try XCTUnwrap(try result.get(forField: "times") as? [DynamicMessage])
        XCTAssertEqual(times.count, 2)
        XCTAssertEqual(try times[0].get(forField: "seconds") as? Int64, 0)
        XCTAssertEqual(try times[1].get(forField: "seconds") as? Int64, 946_684_800)
    }

    func test_TS10_timestamp_nestedUnderCustomMessage() throws {
        var eventDesc = MessageDescriptor(name: "Event", parent: file)
        eventDesc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))

        var rootDesc = MessageDescriptor(name: "Root", parent: file)
        rootDesc.addField(FieldDescriptor(
            name: "event", number: 1, type: .message, typeName: "test.Event"))
        let reg = registry(with: [eventDesc, rootDesc])

        let result = try parse(
            #"{"event": {"ts": "2000-01-01T00:00:00Z"}}"#,
            descriptor: rootDesc, registry: reg)

        let event = try XCTUnwrap(try result.get(forField: "event") as? DynamicMessage)
        let ts = try XCTUnwrap(try event.get(forField: "ts") as? DynamicMessage)
        XCTAssertEqual(try ts.get(forField: "seconds") as? Int64, 946_684_800)
    }

    func test_TS11_timestamp_mixedRepeated_stringAndObject() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "times", number: 1, type: .message,
            typeName: WellKnownTypeNames.timestamp, isRepeated: true))
        let reg = registry(with: [desc])

        let result = try parse(
            #"{"times": ["1970-01-01T00:00:00Z", {"seconds": 100, "nanos": 0}]}"#,
            descriptor: desc, registry: reg)

        let times = try XCTUnwrap(try result.get(forField: "times") as? [DynamicMessage])
        XCTAssertEqual(times.count, 2)
        XCTAssertEqual(try times[0].get(forField: "seconds") as? Int64, 0)
        XCTAssertEqual(try times[1].get(forField: "seconds") as? Int64, 100)
    }

    func test_TS12_timestamp_emptyString_throws() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"{"ts": ""}"#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    func test_TS13_timestamp_invalidString_throws() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"{"ts": "not-a-date"}"#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    // MARK: - §11.2 WKT Duration

    func test_DUR1_positiveIntegerSeconds() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        let result = try parse(#"{"dur": "10s"}"#, descriptor: desc, registry: reg)

        let dur = try XCTUnwrap(try result.get(forField: "dur") as? DynamicMessage)
        XCTAssertEqual(try dur.get(forField: "seconds") as? Int64, 10)
        XCTAssertEqual(try dur.get(forField: "nanos") as? Int32, 0)
    }

    func test_DUR2_positiveFractional() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        let result = try parse(#"{"dur": "1.5s"}"#, descriptor: desc, registry: reg)

        let dur = try XCTUnwrap(try result.get(forField: "dur") as? DynamicMessage)
        XCTAssertEqual(try dur.get(forField: "seconds") as? Int64, 1)
        XCTAssertEqual(try dur.get(forField: "nanos") as? Int32, 500_000_000)
    }

    func test_DUR3_zero() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        let result = try parse(#"{"dur": "0s"}"#, descriptor: desc, registry: reg)

        let dur = try XCTUnwrap(try result.get(forField: "dur") as? DynamicMessage)
        XCTAssertEqual(try dur.get(forField: "seconds") as? Int64, 0)
        XCTAssertEqual(try dur.get(forField: "nanos") as? Int32, 0)
    }

    func test_DUR6_objectForm_passThrough() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        let result = try parse(#"{"dur": {"seconds": 1, "nanos": 500000000}}"#, descriptor: desc, registry: reg)

        let dur = try XCTUnwrap(try result.get(forField: "dur") as? DynamicMessage)
        XCTAssertEqual(try dur.get(forField: "seconds") as? Int64, 1)
        XCTAssertEqual(try dur.get(forField: "nanos") as? Int32, 500_000_000)
    }

    func test_DUR8_mixedRepeated_stringAndObject() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "durs", number: 1, type: .message,
            typeName: WellKnownTypeNames.duration, isRepeated: true))
        let reg = registry(with: [desc])

        let result = try parse(
            #"{"durs": ["1s", {"seconds": 2, "nanos": 0}]}"#,
            descriptor: desc, registry: reg)

        let durs = try XCTUnwrap(try result.get(forField: "durs") as? [DynamicMessage])
        XCTAssertEqual(durs.count, 2)
        XCTAssertEqual(try durs[0].get(forField: "seconds") as? Int64, 1)
        XCTAssertEqual(try durs[1].get(forField: "seconds") as? Int64, 2)
    }

    func test_DUR9_missingSuffix_throws() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"{"dur": "10"}"#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    func test_DUR10_emptyString_throws() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"{"dur": ""}"#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    func test_DUR11_onlySuffix_throws() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"{"dur": "s"}"#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    func test_DUR12_nonNumeric_throws() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"{"dur": "abcs"}"#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    // MARK: - §11.3 WKT Empty

    func test_EM1_emptyObject() throws {
        let pool = DescriptorPool(includeBuiltinDescriptors: true)
        let emptyDesc = try XCTUnwrap(pool.findMessageDescriptor(named: WellKnownTypeNames.empty))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "e", number: 1, type: .message, typeName: WellKnownTypeNames.empty))
        let reg = registry(with: [desc])

        let result = try parse(#"{"e": {}}"#, descriptor: desc, registry: reg)

        let e = try XCTUnwrap(try result.get(forField: "e") as? DynamicMessage)
        XCTAssertEqual(e.descriptor.fullName, emptyDesc.fullName)
    }

    func test_EM2_omittedField() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "e", number: 1, type: .message, typeName: WellKnownTypeNames.empty))
        desc.addField(FieldDescriptor(name: "name", number: 2, type: .string))
        let reg = registry(with: [desc])

        let result = try parse(#"{"name": "test"}"#, descriptor: desc, registry: reg)

        let hasE = try result.hasValue(forField: "e")
        XCTAssertFalse(hasE)
    }

    // MARK: - §12 Oneof

    func test_O1_oneofBranchA_scalar() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addOneofDecl(OneofDescriptor(name: "contact", index: 0))
        desc.addField(FieldDescriptor(name: "str_val", number: 1, type: .string, oneofIndex: 0))
        desc.addField(FieldDescriptor(name: "int_val", number: 2, type: .int32, oneofIndex: 0))
        let reg = registry(with: [desc])

        let result = try parse(#"{"str_val": "hello"}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set("hello", forField: "str_val")
        XCTAssertEqual(result, expected)
        XCTAssertFalse(try result.hasValue(forField: "int_val"))
    }

    func test_O2_oneofBranchB_message() throws {
        var subDesc = MessageDescriptor(name: "Sub", parent: file)
        subDesc.addField(FieldDescriptor(name: "x", number: 1, type: .int32))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addOneofDecl(OneofDescriptor(name: "contact", index: 0))
        desc.addField(FieldDescriptor(name: "str_val", number: 1, type: .string, oneofIndex: 0))
        desc.addField(FieldDescriptor(
            name: "msg_val", number: 2, type: .message, typeName: "test.Sub", oneofIndex: 0))
        let reg = registry(with: [subDesc, desc])

        let result = try parse(#"{"msg_val": {"x": 1}}"#, descriptor: desc, registry: reg)

        XCTAssertTrue(try result.hasValue(forField: "msg_val"))
        XCTAssertFalse(try result.hasValue(forField: "str_val"))
        let sub = try XCTUnwrap(try result.get(forField: "msg_val") as? DynamicMessage)
        XCTAssertEqual(try sub.get(forField: "x") as? Int32, 1)
    }

    func test_O4_oneofNoBranchSet() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addOneofDecl(OneofDescriptor(name: "contact", index: 0))
        desc.addField(FieldDescriptor(name: "str_val", number: 1, type: .string, oneofIndex: 0))
        desc.addField(FieldDescriptor(name: "int_val", number: 2, type: .int32, oneofIndex: 0))
        let reg = registry(with: [desc])

        let result = try parse(#"{}"#, descriptor: desc, registry: reg)

        XCTAssertFalse(try result.hasValue(forField: "str_val"))
        XCTAssertFalse(try result.hasValue(forField: "int_val"))
    }

    // MARK: - §13 Root JSON Shape

    func test_T1_rootObject() throws {
        let desc = MessageDescriptor(name: "Msg", parent: file)
        let reg = registry(with: [desc])

        let result = try parse(#"{}"#, descriptor: desc, registry: reg)

        let expected = MessageFactory().createMessage(from: desc)
        XCTAssertEqual(result, expected)
    }

    func test_T2_rootArray_throws() {
        let desc = MessageDescriptor(name: "Msg", parent: file)
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"[]"#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    func test_T3_rootString_throws() {
        let desc = MessageDescriptor(name: "Msg", parent: file)
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#""hello""#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    func test_T4_rootNumber_throws() {
        let desc = MessageDescriptor(name: "Msg", parent: file)
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"42"#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    func test_T5_rootNull_throws() {
        let desc = MessageDescriptor(name: "Msg", parent: file)
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"null"#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    func test_T6_rootBool_throws() {
        let desc = MessageDescriptor(name: "Msg", parent: file)
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"true"#, descriptor: desc, registry: reg)) { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    func test_T8_malformedJSON_throws() {
        let desc = MessageDescriptor(name: "Msg", parent: file)
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse(#"{invalid"#, descriptor: desc, registry: reg))
    }

    func test_T9_emptyString_throws() {
        let desc = MessageDescriptor(name: "Msg", parent: file)
        let reg = registry(with: [desc])

        XCTAssertThrowsError(try parse("", descriptor: desc, registry: reg))
    }

    // MARK: - §14 Unknown Fields

    func test_U1_unknownField_ignored() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "name", number: 1, type: .string))
        let reg = registry(with: [desc])

        let result = try parse(#"{"name": "alice", "bogus": 42}"#, descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set("alice", forField: "name")
        XCTAssertEqual(result, expected)
    }

    func test_U2_multipleUnknownFields_allIgnored() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "name", number: 1, type: .string))
        let reg = registry(with: [desc])

        let result = try parse(
            #"{"name": "alice", "x": 1, "y": true, "z": "zzz"}"#,
            descriptor: desc, registry: reg)

        var expected = MessageFactory().createMessage(from: desc)
        try expected.set("alice", forField: "name")
        XCTAssertEqual(result, expected)
    }

    // MARK: - §15 Default Values

    func test_D1_allFieldsAbsent_defaultMessage() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "count", number: 1, type: .int32))
        desc.addField(FieldDescriptor(name: "name", number: 2, type: .string))
        desc.addField(FieldDescriptor(name: "flag", number: 3, type: .bool))
        let reg = registry(with: [desc])

        let result = try parse(#"{}"#, descriptor: desc, registry: reg)

        let expected = MessageFactory().createMessage(from: desc)
        XCTAssertEqual(result, expected)
    }

    func test_D2_scalarZeroValue_sameAsAbsent() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "count", number: 1, type: .int32))
        let reg = registry(with: [desc])

        let withZero = try parse(#"{"count": 0}"#, descriptor: desc, registry: reg)
        let withAbsent = try parse(#"{}"#, descriptor: desc, registry: reg)

        let valZero = try (withZero.get(forField: "count") as? Int) ?? 0
        let valAbsent = try (withAbsent.get(forField: "count") as? Int) ?? 0
        XCTAssertEqual(valZero, 0)
        XCTAssertEqual(valAbsent, 0)
    }

    func test_D3_emptyString_sameAsAbsent() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "name", number: 1, type: .string))
        let reg = registry(with: [desc])

        let withEmpty = try parse(#"{"name": ""}"#, descriptor: desc, registry: reg)
        let withAbsent = try parse(#"{}"#, descriptor: desc, registry: reg)

        let valEmpty = try (withEmpty.get(forField: "name") as? String) ?? ""
        let valAbsent = try (withAbsent.get(forField: "name") as? String) ?? ""
        XCTAssertEqual(valEmpty, "")
        XCTAssertEqual(valAbsent, "")
    }

    func test_D4_boolFalse_sameAsAbsent() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "flag", number: 1, type: .bool))
        let reg = registry(with: [desc])

        let withFalse = try parse(#"{"flag": false}"#, descriptor: desc, registry: reg)
        let withAbsent = try parse(#"{}"#, descriptor: desc, registry: reg)

        let valFalse = try (withFalse.get(forField: "flag") as? Bool) ?? false
        let valAbsent = try (withAbsent.get(forField: "flag") as? Bool) ?? false
        XCTAssertEqual(valFalse, false)
        XCTAssertEqual(valAbsent, false)
    }

    // MARK: - §16 Negative / Error Catalog — WKT Map

    func test_M8_mapTimestampString_normalizedToObject() throws {
        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(
                name: "value", number: 2, type: .message,
                typeName: WellKnownTypeNames.timestamp))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts_map", number: 1, type: .message,
            typeName: "test.Msg.TsMapEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = registry(with: [desc])

        let result = try parse(
            #"{"ts_map": {"k": "1970-01-01T00:00:00Z"}}"#,
            descriptor: desc, registry: reg)

        let mapVal = try XCTUnwrap(try result.get(forField: "ts_map") as? [AnyHashable: Any])
        let ts = try XCTUnwrap(mapVal["k"] as? DynamicMessage)
        XCTAssertEqual(try ts.get(forField: "seconds") as? Int64, 0)
    }

    func test_M10_mapDurationString_normalizedToObject() throws {
        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(
                name: "value", number: 2, type: .message,
                typeName: WellKnownTypeNames.duration))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "dur_map", number: 1, type: .message,
            typeName: "test.Msg.DurMapEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = registry(with: [desc])

        let result = try parse(
            #"{"dur_map": {"k": "1.5s"}}"#,
            descriptor: desc, registry: reg)

        let mapVal = try XCTUnwrap(try result.get(forField: "dur_map") as? [AnyHashable: Any])
        let dur = try XCTUnwrap(mapVal["k"] as? DynamicMessage)
        XCTAssertEqual(try dur.get(forField: "seconds") as? Int64, 1)
        XCTAssertEqual(try dur.get(forField: "nanos") as? Int32, 500_000_000)
    }
}

// swiftlint:enable file_length type_body_length
