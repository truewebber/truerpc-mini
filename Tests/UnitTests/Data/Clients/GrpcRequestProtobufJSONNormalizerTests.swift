import SwiftProtoReflect
import XCTest
@testable import TrueRPCMini

/// Unit tests for `GrpcRequestProtobufJSONNormalizer` in isolation.
///
/// Input: `[String: Any]` + `MessageDescriptor` + `TypeRegistry`
/// Output: `[String: Any]` — the rewritten JSON object ready for `JSONDeserializer`.
///
/// SwiftProtoReflect v6 handles `google.protobuf.Timestamp` (RFC 3339 string) and
/// `google.protobuf.Duration` (`"1.5s"` string) natively. The normalizer no longer
/// converts those strings — it only recurses into ordinary nested message fields.
///
/// Covers test plan §17.1.
final class GrpcRequestProtobufJSONNormalizerTests: XCTestCase {
    private let file = FileDescriptor(name: "test.proto", package: "test")

    private func registry(with descriptors: [MessageDescriptor] = []) async -> TypeRegistry {
        let reg = TypeRegistry()
        let pool = DescriptorPool(includeBuiltinDescriptors: true)
        for name in await pool.allMessageTypeNames() {
            if let desc = await pool.findMessageDescriptor(named: name) {
                try? await reg.registerMessage(desc)
            }
        }
        for desc in descriptors {
            try? await reg.registerMessage(desc)
        }
        return reg
    }

    // MARK: - Scalar Pass-Through

    func test_scalarFields_passedThrough_unchanged() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "name", number: 1, type: .string))
        desc.addField(FieldDescriptor(name: "age", number: 2, type: .int32))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["name": "alice", "age": 30]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        XCTAssertEqual(result["name"] as? String, "alice")
        XCTAssertEqual(result["age"] as? Int, 30)
    }

    // MARK: - Unknown Fields Pass-Through

    func test_unknownFields_passedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "name", number: 1, type: .string))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["name": "alice", "bogus": 42]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        XCTAssertEqual(result["bogus"] as? Int, 42)
    }

    // MARK: - Timestamp Pass-Through (v6 handles RFC 3339 strings natively)

    func test_timestamp_singular_stringPassedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["ts": "1970-01-01T00:00:00Z"]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        XCTAssertEqual(
            result["ts"] as? String,
            "1970-01-01T00:00:00Z",
            "v6 handles RFC 3339 strings natively — normalizer must pass them through unchanged")
    }

    func test_timestamp_singular_objectPassedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["ts": ["seconds": NSNumber(value: 100), "nanos": NSNumber(value: 0)]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let tsObj = try XCTUnwrap(result["ts"] as? [String: Any])
        XCTAssertEqual((tsObj["seconds"] as? NSNumber)?.int64Value, 100)
    }

    func test_timestamp_emptyString_passedThrough_withoutThrow() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = await registry(with: [desc])

        // Normalizer no longer validates WKT strings; empty string passes through to JSONDeserializer
        let input: [String: Any] = ["ts": ""]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)
        XCTAssertEqual(result["ts"] as? String, "")
    }

    func test_timestamp_invalidDate_passedThrough_withoutThrow() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = await registry(with: [desc])

        // Normalizer no longer validates WKT strings; invalid dates pass through to JSONDeserializer
        let input: [String: Any] = ["ts": "not-a-date"]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)
        XCTAssertEqual(result["ts"] as? String, "not-a-date")
    }

    // MARK: - Duration Pass-Through (v6 handles duration strings natively)

    func test_duration_singular_stringPassedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["dur": "1.5s"]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        XCTAssertEqual(
            result["dur"] as? String,
            "1.5s",
            "v6 handles duration strings natively — normalizer must pass them through unchanged")
    }

    func test_duration_zeroSeconds_passedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["dur": "0s"]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        XCTAssertEqual(result["dur"] as? String, "0s")
    }

    func test_duration_missingSuffix_passedThrough_withoutThrow() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = await registry(with: [desc])

        // Normalizer no longer validates WKT strings; passes through to JSONDeserializer
        let input: [String: Any] = ["dur": "10"]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)
        XCTAssertEqual(result["dur"] as? String, "10")
    }

    // MARK: - Repeated WKT Pass-Through

    func test_repeatedTimestamp_stringsPassedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "times", number: 1, type: .message,
            typeName: WellKnownTypeNames.timestamp, isRepeated: true))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["times": ["1970-01-01T00:00:00Z", "2000-01-01T00:00:00Z"]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let times = try XCTUnwrap(result["times"] as? [String])
        XCTAssertEqual(times.count, 2)
        XCTAssertEqual(times[0], "1970-01-01T00:00:00Z")
        XCTAssertEqual(times[1], "2000-01-01T00:00:00Z")
    }

    func test_repeatedTimestamp_mixedStringAndObject_passedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "times", number: 1, type: .message,
            typeName: WellKnownTypeNames.timestamp, isRepeated: true))
        let reg = await registry(with: [desc])

        let input: [String: Any] = [
            "times": [
                "1970-01-01T00:00:00Z",
                ["seconds": NSNumber(value: 100), "nanos": NSNumber(value: 0)] as [String: Any],
            ] as [Any],
        ]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let times = try XCTUnwrap(result["times"] as? [Any])
        XCTAssertEqual(times.count, 2)
        XCTAssertEqual(times[0] as? String, "1970-01-01T00:00:00Z")
        let t1 = try XCTUnwrap(times[1] as? [String: Any])
        XCTAssertEqual((t1["seconds"] as? NSNumber)?.int64Value, 100)
    }

    func test_repeatedDuration_stringsPassedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "durs", number: 1, type: .message,
            typeName: WellKnownTypeNames.duration, isRepeated: true))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["durs": ["1s", "0.5s"]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let durs = try XCTUnwrap(result["durs"] as? [String])
        XCTAssertEqual(durs.count, 2)
        XCTAssertEqual(durs[0], "1s")
        XCTAssertEqual(durs[1], "0.5s")
    }

    // MARK: - Map Value Pass-Through for WKT

    func test_mapTimestamp_valuesPassedThrough() async throws {
        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(
                name: "value", number: 2, type: .message,
                typeName: WellKnownTypeNames.timestamp))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts_map", number: 1, type: .message,
            typeName: "test.Msg.TsMapEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["ts_map": ["alice": "1970-01-01T00:00:00Z"]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let mapVal = try XCTUnwrap(result["ts_map"] as? [String: Any])
        XCTAssertEqual(
            mapVal["alice"] as? String,
            "1970-01-01T00:00:00Z",
            "Timestamp map values must pass through as strings for v6")
    }

    func test_mapDuration_valuesPassedThrough() async throws {
        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(
                name: "value", number: 2, type: .message,
                typeName: WellKnownTypeNames.duration))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "dur_map", number: 1, type: .message,
            typeName: "test.Msg.DurMapEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["dur_map": ["k": "1.5s"]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let mapVal = try XCTUnwrap(result["dur_map"] as? [String: Any])
        XCTAssertEqual(
            mapVal["k"] as? String,
            "1.5s",
            "Duration map values must pass through as strings for v6")
    }

    // MARK: - Recursive Descent (non-WKT messages still recursed into)

    func test_nestedMessage_recursivelyEntered_wktStringPassedThrough() async throws {
        var eventDesc = MessageDescriptor(name: "Event", parent: file)
        eventDesc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))

        var rootDesc = MessageDescriptor(name: "Root", parent: file)
        rootDesc.addField(FieldDescriptor(
            name: "event", number: 1, type: .message, typeName: "test.Event"))
        let reg = await registry(with: [eventDesc, rootDesc])

        let input: [String: Any] = ["event": ["ts": "2000-01-01T00:00:00Z"]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: rootDesc, typeRegistry: reg)

        let event = try XCTUnwrap(result["event"] as? [String: Any])
        XCTAssertEqual(
            event["ts"] as? String,
            "2000-01-01T00:00:00Z",
            "Normalizer recurses into non-WKT messages; WKT string inside is passed through unchanged")
    }

    func test_deepNesting_timestampAtDepth3_passedThrough() async throws {
        var cDesc = MessageDescriptor(name: "C", parent: file)
        cDesc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))

        var bDesc = MessageDescriptor(name: "B", parent: file)
        bDesc.addField(FieldDescriptor(
            name: "c", number: 1, type: .message, typeName: "test.C"))

        var aDesc = MessageDescriptor(name: "A", parent: file)
        aDesc.addField(FieldDescriptor(
            name: "b", number: 1, type: .message, typeName: "test.B"))
        let reg = await registry(with: [cDesc, bDesc, aDesc])

        let input: [String: Any] = ["b": ["c": ["ts": "1970-01-01T00:00:00Z"]]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: aDesc, typeRegistry: reg)

        let b = try XCTUnwrap(result["b"] as? [String: Any])
        let c = try XCTUnwrap(b["c"] as? [String: Any])
        XCTAssertEqual(c["ts"] as? String, "1970-01-01T00:00:00Z")
    }

    // MARK: - json_name Resolution in Normalizer

    func test_jsonName_camelCaseKey_fieldFoundAndValuePassedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "created_at", number: 1, type: .message,
            typeName: WellKnownTypeNames.timestamp, jsonName: "createdAt"))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["createdAt": "1970-01-01T00:00:00Z"]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        XCTAssertEqual(
            result["createdAt"] as? String,
            "1970-01-01T00:00:00Z",
            "camelCase json_name key is resolved to field and WKT value passes through")
    }

    func test_jsonName_snakeCaseKey_fieldFoundAndValuePassedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "created_at", number: 1, type: .message,
            typeName: WellKnownTypeNames.timestamp, jsonName: "createdAt"))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["created_at": "1970-01-01T00:00:00Z"]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        XCTAssertEqual(
            result["created_at"] as? String,
            "1970-01-01T00:00:00Z",
            "snake_case field name is resolved and WKT value passes through")
    }

    // MARK: - Repeated Non-WKT Message

    func test_repeatedMessage_recursivelyNormalized_scalarFieldsPreserved() async throws {
        var itemDesc = MessageDescriptor(name: "Item", parent: file)
        itemDesc.addField(FieldDescriptor(name: "name", number: 1, type: .string))
        itemDesc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))

        var rootDesc = MessageDescriptor(name: "Root", parent: file)
        rootDesc.addField(FieldDescriptor(
            name: "items", number: 1, type: .message,
            typeName: "test.Item", isRepeated: true))
        let reg = await registry(with: [itemDesc, rootDesc])

        let input: [String: Any] = [
            "items": [
                ["name": "x", "ts": "1970-01-01T00:00:00Z"],
            ] as [[String: Any]],
        ]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: rootDesc, typeRegistry: reg)

        let items = try XCTUnwrap(result["items"] as? [Any])
        let firstItem = try XCTUnwrap(items[0] as? [String: Any])
        XCTAssertEqual(firstItem["name"] as? String, "x")
        XCTAssertEqual(
            firstItem["ts"] as? String,
            "1970-01-01T00:00:00Z",
            "WKT inside repeated non-WKT message passes through as string")
    }

    // MARK: - Map Non-WKT Value Messages

    func test_mapMessageValues_recursivelyNormalized_scalarFieldsPreserved() async throws {
        var subDesc = MessageDescriptor(name: "Sub", parent: file)
        subDesc.addField(FieldDescriptor(name: "label", number: 1, type: .string))
        subDesc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))

        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(
                name: "value", number: 2, type: .message, typeName: "test.Sub"))

        var rootDesc = MessageDescriptor(name: "Root", parent: file)
        rootDesc.addField(FieldDescriptor(
            name: "subs", number: 1, type: .message,
            typeName: "test.Root.SubsEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = await registry(with: [subDesc, rootDesc])

        let input: [String: Any] = ["subs": ["k": ["label": "y", "ts": "1970-01-01T00:00:00Z"]]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: rootDesc, typeRegistry: reg)

        let subs = try XCTUnwrap(result["subs"] as? [String: Any])
        let sub = try XCTUnwrap(subs["k"] as? [String: Any])
        XCTAssertEqual(sub["label"] as? String, "y")
        XCTAssertEqual(
            sub["ts"] as? String,
            "1970-01-01T00:00:00Z",
            "WKT inside map non-WKT message passes through as string")
    }

    // MARK: - Leading-dot typeName (real DescriptorBridge output)

    func test_timestamp_leadingDotTypeName_stringPassedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: ".\(WellKnownTypeNames.timestamp)"))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["ts": "1970-01-01T00:00:00Z"]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        XCTAssertEqual(
            result["ts"] as? String,
            "1970-01-01T00:00:00Z",
            "Timestamp string must pass through even when typeName has a leading dot")
    }

    func test_nestedMessage_leadingDotTypeName_recursivelyNormalized_wktPassedThrough() async throws {
        var innerDesc = MessageDescriptor(name: "Inner", parent: file)
        innerDesc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: ".\(WellKnownTypeNames.timestamp)"))

        var outerDesc = MessageDescriptor(name: "Outer", parent: file)
        outerDesc.addField(FieldDescriptor(
            name: "inner", number: 1, type: .message, typeName: ".test.Inner"))

        let reg = await registry(with: [outerDesc, innerDesc])

        let input: [String: Any] = ["inner": ["ts": "1970-01-01T00:00:00Z"]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: outerDesc, typeRegistry: reg)

        let inner = try XCTUnwrap(result["inner"] as? [String: Any])
        XCTAssertEqual(
            inner["ts"] as? String,
            "1970-01-01T00:00:00Z",
            "Timestamp inside nested message passes through when outer typeName has a leading dot")
    }

    // MARK: - Repeated Scalar (no normalization needed)

    func test_repeatedScalar_passedThrough() async throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "tags", number: 1, type: .string, isRepeated: true))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["tags": ["a", "b"]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let tags = try XCTUnwrap(result["tags"] as? [String])
        XCTAssertEqual(tags, ["a", "b"])
    }

    // MARK: - Map Scalar Values (no normalization needed)

    func test_mapScalarValues_passedThrough() async throws {
        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(name: "value", number: 2, type: .string))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "labels", number: 1, type: .message,
            typeName: "test.Msg.LabelsEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = await registry(with: [desc])

        let input: [String: Any] = ["labels": ["a": "x"]]
        let result = try await GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let labels = try XCTUnwrap(result["labels"] as? [String: Any])
        XCTAssertEqual(labels["a"] as? String, "x")
    }
}
