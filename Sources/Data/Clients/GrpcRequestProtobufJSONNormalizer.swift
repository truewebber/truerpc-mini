import Foundation
import SwiftProtoReflect

/// Recursively normalises a protobuf-JSON object so that nested non-WKT messages are pre-processed
/// before passing to `SwiftProtoReflect.JSONDeserializer`.
///
/// **SwiftProtoReflect v6** handles `google.protobuf.Timestamp` (RFC 3339 string) and
/// `google.protobuf.Duration` (`"1.5s"` string) natively, so this normalizer no longer converts
/// those strings — it only recurses into ordinary nested message fields.
enum GrpcRequestProtobufJSONNormalizer {
    /// Rewrites a root JSON object in place according to `descriptor` (nested messages, repeated, maps).
    static func normalizeMessageObject(
        _ object: [String: Any],
        descriptor: MessageDescriptor,
        typeRegistry: TypeRegistry)
        async throws -> [String: Any]
    {
        var result: [String: Any] = [:]
        result.reserveCapacity(object.count)

        for (key, value) in object {
            guard let field = field(matchingJSONKey: key, in: descriptor) else {
                result[key] = value
                continue
            }

            result[key] = try await normalizeFieldValue(value, field: field, typeRegistry: typeRegistry)
        }

        return result
    }

    private static func field(matchingJSONKey key: String, in descriptor: MessageDescriptor) -> FieldDescriptor? {
        for field in descriptor.allFields() where field.name == key || field.jsonName == key {
            return field
        }
        return nil
    }

    private static func normalizeFieldValue(
        _ value: Any,
        field: FieldDescriptor,
        typeRegistry: TypeRegistry)
        async throws -> Any
    {
        if field.isMap, let info = field.mapEntryInfo {
            return try await normalizeMapValue(value, mapInfo: info, typeRegistry: typeRegistry)
        }

        if field.isRepeated {
            if field.type == .message, let typeName = field.typeName {
                return try await normalizeRepeatedMessageValue(
                    value,
                    typeName: stripLeadingDot(typeName),
                    typeRegistry: typeRegistry)
            }
            return value
        }

        if field.type == .message, let typeName = field.typeName {
            return try await normalizeSingularMessageValue(
                value,
                typeName: stripLeadingDot(typeName),
                typeRegistry: typeRegistry)
        }

        return value
    }

    /// Strips a leading `.` from a protobuf fully-qualified type name.
    ///
    /// `FieldDescriptorProto.type_name` always starts with `.` (e.g. `.google.protobuf.Timestamp`),
    /// but `WellKnownTypeNames` constants and `TypeRegistry` keys do not include it.
    private static func stripLeadingDot(_ typeName: String) -> String {
        typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName
    }

    private static func normalizeMapValue(
        _ value: Any,
        mapInfo: MapEntryInfo,
        typeRegistry: TypeRegistry)
        async throws -> Any
    {
        guard let mapObject = value as? [String: Any] else {
            return value
        }

        var out: [String: Any] = [:]
        out.reserveCapacity(mapObject.count)

        for (key, entryValue) in mapObject {
            if mapInfo.valueFieldInfo.type == .message, let valueTypeName = mapInfo.valueFieldInfo.typeName {
                out[key] = try await normalizeSingularMessageValue(
                    entryValue,
                    typeName: stripLeadingDot(valueTypeName),
                    typeRegistry: typeRegistry)
            } else {
                out[key] = entryValue
            }
        }

        return out
    }

    private static func normalizeRepeatedMessageValue(
        _ value: Any,
        typeName: String,
        typeRegistry: TypeRegistry)
        async throws -> Any
    {
        guard let array = value as? [Any] else {
            return value
        }

        // WKT Timestamp and Duration: v6 deserialises the canonical string form natively — pass through.
        if typeName == WellKnownTypeNames.timestamp || typeName == WellKnownTypeNames.duration {
            return array
        }

        guard let nested = await typeRegistry.findMessage(named: typeName) else {
            return value
        }

        var normalized: [Any] = []
        normalized.reserveCapacity(array.count)
        for element in array {
            guard var object = element as? [String: Any] else {
                normalized.append(element)
                continue
            }

            object = try await normalizeMessageObject(object, descriptor: nested, typeRegistry: typeRegistry)
            normalized.append(object)
        }
        return normalized
    }

    private static func normalizeSingularMessageValue(
        _ value: Any,
        typeName: String,
        typeRegistry: TypeRegistry)
        async throws -> Any
    {
        // WKT Timestamp and Duration: v6 deserialises the canonical string form natively — pass through.
        if typeName == WellKnownTypeNames.timestamp || typeName == WellKnownTypeNames.duration {
            return value
        }

        guard var object = value as? [String: Any],
              let nested = await typeRegistry.findMessage(named: typeName)
        else {
            return value
        }

        object = try await normalizeMessageObject(object, descriptor: nested, typeRegistry: typeRegistry)
        return object
    }
}
