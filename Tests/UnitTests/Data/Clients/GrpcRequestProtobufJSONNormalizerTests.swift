import SwiftProtoReflect
import XCTest
@testable import TrueRPCMini

/// Unit tests for `GrpcRequestProtobufJSONNormalizer` in isolation.
///
/// Input: `[String: Any]` + `MessageDescriptor` + `TypeRegistry`
/// Output: `[String: Any]` — the rewritten JSON object ready for `JSONDeserializer`.
///
/// Covers test plan §17.1.
final class GrpcRequestProtobufJSONNormalizerTests: XCTestCase {
    private let file = FileDescriptor(name: "test.proto", package: "test")

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

    // MARK: - Scalar Pass-Through

    func test_scalarFields_passedThrough_unchanged() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "name", number: 1, type: .string))
        desc.addField(FieldDescriptor(name: "age", number: 2, type: .int32))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["name": "alice", "age": 30]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        XCTAssertEqual(result["name"] as? String, "alice")
        XCTAssertEqual(result["age"] as? Int, 30)
    }

    // MARK: - Unknown Fields Pass-Through

    func test_unknownFields_passedThrough() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "name", number: 1, type: .string))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["name": "alice", "bogus": 42]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        XCTAssertEqual(result["bogus"] as? Int, 42)
    }

    // MARK: - Timestamp Normalization

    func test_timestamp_singular_stringConvertedToObject() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["ts": "1970-01-01T00:00:00Z"]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let tsObj = try XCTUnwrap(result["ts"] as? [String: Any])
        XCTAssertEqual((tsObj["seconds"] as? NSNumber)?.int64Value, 0)
        XCTAssertEqual((tsObj["nanos"] as? NSNumber)?.int32Value, 0)
    }

    func test_timestamp_singular_objectPassedThrough() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["ts": ["seconds": NSNumber(value: 100), "nanos": NSNumber(value: 0)]]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let tsObj = try XCTUnwrap(result["ts"] as? [String: Any])
        XCTAssertEqual((tsObj["seconds"] as? NSNumber)?.int64Value, 100)
    }

    func test_timestamp_emptyString_throws() {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["ts": ""]
        XCTAssertThrowsError(
            try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
                input, descriptor: desc, typeRegistry: reg))
        { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    func test_timestamp_invalidDate_throws() {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["ts": "not-a-date"]
        XCTAssertThrowsError(
            try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
                input, descriptor: desc, typeRegistry: reg))
        { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    // MARK: - Duration Normalization

    func test_duration_singular_stringConvertedToObject() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["dur": "1.5s"]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let durObj = try XCTUnwrap(result["dur"] as? [String: Any])
        XCTAssertEqual((durObj["seconds"] as? NSNumber)?.int64Value, 1)
        XCTAssertEqual((durObj["nanos"] as? NSNumber)?.int32Value, 500_000_000)
    }

    func test_duration_zeroSeconds() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["dur": "0s"]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let durObj = try XCTUnwrap(result["dur"] as? [String: Any])
        XCTAssertEqual((durObj["seconds"] as? NSNumber)?.int64Value, 0)
        XCTAssertEqual((durObj["nanos"] as? NSNumber)?.int32Value, 0)
    }

    func test_duration_missingSuffix_throws() {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "dur", number: 1, type: .message, typeName: WellKnownTypeNames.duration))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["dur": "10"]
        XCTAssertThrowsError(
            try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
                input, descriptor: desc, typeRegistry: reg))
        { error in
            guard case GrpcClientError.invalidJSON = error else {
                XCTFail("Expected GrpcClientError.invalidJSON, got \(error)")
                return
            }
        }
    }

    // MARK: - Repeated WKT

    func test_repeatedTimestamp_allStringsConverted() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "times", number: 1, type: .message,
            typeName: WellKnownTypeNames.timestamp, isRepeated: true))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["times": ["1970-01-01T00:00:00Z", "2000-01-01T00:00:00Z"]]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let times = try XCTUnwrap(result["times"] as? [Any])
        XCTAssertEqual(times.count, 2)

        let t0 = try XCTUnwrap(times[0] as? [String: Any])
        XCTAssertEqual((t0["seconds"] as? NSNumber)?.int64Value, 0)

        let t1 = try XCTUnwrap(times[1] as? [String: Any])
        XCTAssertEqual((t1["seconds"] as? NSNumber)?.int64Value, 946_684_800)
    }

    func test_repeatedTimestamp_mixedStringAndObject() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "times", number: 1, type: .message,
            typeName: WellKnownTypeNames.timestamp, isRepeated: true))
        let reg = registry(with: [desc])

        let input: [String: Any] = [
            "times": [
                "1970-01-01T00:00:00Z",
                ["seconds": NSNumber(value: 100), "nanos": NSNumber(value: 0)] as [String: Any],
            ] as [Any],
        ]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let times = try XCTUnwrap(result["times"] as? [Any])
        XCTAssertEqual(times.count, 2)

        let t0 = try XCTUnwrap(times[0] as? [String: Any])
        XCTAssertEqual((t0["seconds"] as? NSNumber)?.int64Value, 0)

        let t1 = try XCTUnwrap(times[1] as? [String: Any])
        XCTAssertEqual((t1["seconds"] as? NSNumber)?.int64Value, 100)
    }

    func test_repeatedDuration_stringsConverted() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "durs", number: 1, type: .message,
            typeName: WellKnownTypeNames.duration, isRepeated: true))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["durs": ["1s", "0.5s"]]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let durs = try XCTUnwrap(result["durs"] as? [Any])
        XCTAssertEqual(durs.count, 2)

        let d0 = try XCTUnwrap(durs[0] as? [String: Any])
        XCTAssertEqual((d0["seconds"] as? NSNumber)?.int64Value, 1)

        let d1 = try XCTUnwrap(durs[1] as? [String: Any])
        XCTAssertEqual((d1["nanos"] as? NSNumber)?.int32Value, 500_000_000)
    }

    // MARK: - Map Value Normalization

    func test_mapTimestamp_valuesNormalized() throws {
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

        let input: [String: Any] = ["ts_map": ["alice": "1970-01-01T00:00:00Z"]]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let mapVal = try XCTUnwrap(result["ts_map"] as? [String: Any])
        let alice = try XCTUnwrap(mapVal["alice"] as? [String: Any])
        XCTAssertEqual((alice["seconds"] as? NSNumber)?.int64Value, 0)
    }

    func test_mapDuration_valuesNormalized() throws {
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

        let input: [String: Any] = ["dur_map": ["k": "1.5s"]]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let mapVal = try XCTUnwrap(result["dur_map"] as? [String: Any])
        let dur = try XCTUnwrap(mapVal["k"] as? [String: Any])
        XCTAssertEqual((dur["seconds"] as? NSNumber)?.int64Value, 1)
        XCTAssertEqual((dur["nanos"] as? NSNumber)?.int32Value, 500_000_000)
    }

    // MARK: - Recursive Descent

    func test_nestedMessage_recursiveNormalization() throws {
        var eventDesc = MessageDescriptor(name: "Event", parent: file)
        eventDesc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))

        var rootDesc = MessageDescriptor(name: "Root", parent: file)
        rootDesc.addField(FieldDescriptor(
            name: "event", number: 1, type: .message, typeName: "test.Event"))
        let reg = registry(with: [eventDesc, rootDesc])

        let input: [String: Any] = ["event": ["ts": "2000-01-01T00:00:00Z"]]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: rootDesc, typeRegistry: reg)

        let event = try XCTUnwrap(result["event"] as? [String: Any])
        let ts = try XCTUnwrap(event["ts"] as? [String: Any])
        XCTAssertEqual((ts["seconds"] as? NSNumber)?.int64Value, 946_684_800)
    }

    func test_deepNesting_timestampAtDepth3() throws {
        var cDesc = MessageDescriptor(name: "C", parent: file)
        cDesc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))

        var bDesc = MessageDescriptor(name: "B", parent: file)
        bDesc.addField(FieldDescriptor(
            name: "c", number: 1, type: .message, typeName: "test.C"))

        var aDesc = MessageDescriptor(name: "A", parent: file)
        aDesc.addField(FieldDescriptor(
            name: "b", number: 1, type: .message, typeName: "test.B"))
        let reg = registry(with: [cDesc, bDesc, aDesc])

        let input: [String: Any] = ["b": ["c": ["ts": "1970-01-01T00:00:00Z"]]]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: aDesc, typeRegistry: reg)

        let b = try XCTUnwrap(result["b"] as? [String: Any])
        let c = try XCTUnwrap(b["c"] as? [String: Any])
        let ts = try XCTUnwrap(c["ts"] as? [String: Any])
        XCTAssertEqual((ts["seconds"] as? NSNumber)?.int64Value, 0)
    }

    // MARK: - json_name Resolution in Normalizer

    func test_jsonName_camelCaseKey_normalizedCorrectly() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "created_at", number: 1, type: .message,
            typeName: WellKnownTypeNames.timestamp, jsonName: "createdAt"))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["createdAt": "1970-01-01T00:00:00Z"]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let ts = try XCTUnwrap(result["createdAt"] as? [String: Any])
        XCTAssertEqual((ts["seconds"] as? NSNumber)?.int64Value, 0)
    }

    func test_jsonName_snakeCaseKey_alsoNormalized() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "created_at", number: 1, type: .message,
            typeName: WellKnownTypeNames.timestamp, jsonName: "createdAt"))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["created_at": "1970-01-01T00:00:00Z"]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let ts = try XCTUnwrap(result["created_at"] as? [String: Any])
        XCTAssertEqual((ts["seconds"] as? NSNumber)?.int64Value, 0)
    }

    // MARK: - Repeated Non-WKT Message

    func test_repeatedMessage_recursivelyNormalized() throws {
        var itemDesc = MessageDescriptor(name: "Item", parent: file)
        itemDesc.addField(FieldDescriptor(
            name: "ts", number: 1, type: .message, typeName: WellKnownTypeNames.timestamp))

        var rootDesc = MessageDescriptor(name: "Root", parent: file)
        rootDesc.addField(FieldDescriptor(
            name: "items", number: 1, type: .message,
            typeName: "test.Item", isRepeated: true))
        let reg = registry(with: [itemDesc, rootDesc])

        let input: [String: Any] = [
            "items": [
                ["ts": "1970-01-01T00:00:00Z"],
            ] as [[String: Any]],
        ]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: rootDesc, typeRegistry: reg)

        let items = try XCTUnwrap(result["items"] as? [Any])
        let firstItem = try XCTUnwrap(items[0] as? [String: Any])
        let ts = try XCTUnwrap(firstItem["ts"] as? [String: Any])
        XCTAssertEqual((ts["seconds"] as? NSNumber)?.int64Value, 0)
    }

    // MARK: - Map Non-WKT Value Messages

    func test_mapMessageValues_recursivelyNormalized() throws {
        var subDesc = MessageDescriptor(name: "Sub", parent: file)
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
        let reg = registry(with: [subDesc, rootDesc])

        let input: [String: Any] = ["subs": ["k": ["ts": "1970-01-01T00:00:00Z"]]]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: rootDesc, typeRegistry: reg)

        let subs = try XCTUnwrap(result["subs"] as? [String: Any])
        let sub = try XCTUnwrap(subs["k"] as? [String: Any])
        let ts = try XCTUnwrap(sub["ts"] as? [String: Any])
        XCTAssertEqual((ts["seconds"] as? NSNumber)?.int64Value, 0)
    }

    // MARK: - Repeated Scalar (no normalization needed)

    func test_repeatedScalar_passedThrough() throws {
        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(name: "tags", number: 1, type: .string, isRepeated: true))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["tags": ["a", "b"]]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let tags = try XCTUnwrap(result["tags"] as? [String])
        XCTAssertEqual(tags, ["a", "b"])
    }

    // MARK: - Map Scalar Values (no normalization needed)

    func test_mapScalarValues_passedThrough() throws {
        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(name: "value", number: 2, type: .string))

        var desc = MessageDescriptor(name: "Msg", parent: file)
        desc.addField(FieldDescriptor(
            name: "labels", number: 1, type: .message,
            typeName: "test.Msg.LabelsEntry", isMap: true, mapEntryInfo: mapEntry))
        let reg = registry(with: [desc])

        let input: [String: Any] = ["labels": ["a": "x"]]
        let result = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            input, descriptor: desc, typeRegistry: reg)

        let labels = try XCTUnwrap(result["labels"] as? [String: Any])
        XCTAssertEqual(labels["a"] as? String, "x")
    }
}
