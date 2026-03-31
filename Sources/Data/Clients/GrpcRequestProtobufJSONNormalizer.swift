import Foundation
import SwiftProtoReflect

/// Adapts common protobuf JSON forms that `SwiftProtoReflect.JSONDeserializer` does not handle to shapes it accepts.
///
/// Specifically, the official JSON mapping encodes `google.protobuf.Timestamp` as an RFC 3339 **string**, while
/// `JSONDeserializer` only accepts a JSON **object** with `seconds` / `nanos`. This normalizer rewrites those
/// strings (recursively, using field metadata and `TypeRegistry`) before deserialization.
enum GrpcRequestProtobufJSONNormalizer {
    /// Rewrites a root JSON object in place according to `descriptor` (nested messages, repeated, maps).
    static func normalizeMessageObject(
        _ object: [String: Any],
        descriptor: MessageDescriptor,
        typeRegistry: TypeRegistry)
        throws -> [String: Any]
    {
        var result: [String: Any] = [:]
        result.reserveCapacity(object.count)

        for (key, value) in object {
            guard let field = field(matchingJSONKey: key, in: descriptor) else {
                result[key] = value
                continue
            }

            result[key] = try normalizeFieldValue(value, field: field, typeRegistry: typeRegistry)
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
        throws -> Any
    {
        if field.isMap, let info = field.mapEntryInfo {
            return try normalizeMapValue(value, mapInfo: info, typeRegistry: typeRegistry)
        }

        if field.isRepeated {
            if field.type == .message, let typeName = field.typeName {
                return try normalizeRepeatedMessageValue(
                    value,
                    typeName: stripLeadingDot(typeName),
                    typeRegistry: typeRegistry)
            }
            return value
        }

        if field.type == .message, let typeName = field.typeName {
            return try normalizeSingularMessageValue(
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
        throws -> Any
    {
        guard let mapObject = value as? [String: Any] else {
            return value
        }

        var out: [String: Any] = [:]
        out.reserveCapacity(mapObject.count)

        for (key, entryValue) in mapObject {
            if mapInfo.valueFieldInfo.type == .message, let valueTypeName = mapInfo.valueFieldInfo.typeName {
                out[key] = try normalizeSingularMessageValue(
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
        throws -> Any
    {
        guard let array = value as? [Any] else {
            return value
        }

        if typeName == WellKnownTypeNames.timestamp {
            return try normalizeRepeatedWellKnownStringElements(
                array,
                typeName: typeName,
                typeRegistry: typeRegistry,
                convertString: timestampJSONObject(fromRFC3339:))
        }

        if typeName == WellKnownTypeNames.duration {
            return try normalizeRepeatedWellKnownStringElements(
                array,
                typeName: typeName,
                typeRegistry: typeRegistry,
                convertString: durationJSONObject(fromProtoJSONString:))
        }

        guard let nested = typeRegistry.findMessage(named: typeName) else {
            return value
        }

        return try array.map { element -> Any in
            guard var object = element as? [String: Any] else {
                return element
            }

            object = try normalizeMessageObject(object, descriptor: nested, typeRegistry: typeRegistry)
            return object
        }
    }

    private static func normalizeRepeatedWellKnownStringElements(
        _ array: [Any],
        typeName: String,
        typeRegistry: TypeRegistry,
        convertString: (String) throws -> [String: Any])
        throws -> [Any]
    {
        try array.map { element -> Any in
            if let string = element as? String {
                return try convertString(string)
            }
            if var object = element as? [String: Any],
               let descriptor = typeRegistry.findMessage(named: typeName)
            {
                object = try normalizeMessageObject(object, descriptor: descriptor, typeRegistry: typeRegistry)
                return object
            }
            return element
        }
    }

    private static func normalizeSingularMessageValue(
        _ value: Any,
        typeName: String,
        typeRegistry: TypeRegistry)
        throws -> Any
    {
        if typeName == WellKnownTypeNames.timestamp, let string = value as? String {
            return try timestampJSONObject(fromRFC3339: string)
        }

        if typeName == WellKnownTypeNames.duration, let string = value as? String {
            return try durationJSONObject(fromProtoJSONString: string)
        }

        guard var object = value as? [String: Any],
              let nested = typeRegistry.findMessage(named: typeName)
        else {
            return value
        }

        object = try normalizeMessageObject(object, descriptor: nested, typeRegistry: typeRegistry)
        return object
    }

    private static func timestampJSONObject(fromRFC3339 string: String) throws -> [String: Any] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw GrpcClientError.invalidJSON("Empty google.protobuf.Timestamp string")
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: trimmed)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: trimmed)
        }
        guard let parsed = date else {
            throw GrpcClientError.invalidJSON("Invalid RFC 3339 timestamp: \(string)")
        }

        let interval = parsed.timeIntervalSince1970
        let whole = floor(interval)
        let seconds = Int64(whole)
        let nanos = Int32((interval - whole) * 1_000_000_000.0)

        return [
            "seconds": NSNumber(value: seconds),
            "nanos": NSNumber(value: nanos),
        ]
    }

    /// Protobuf JSON mapping for `google.protobuf.Duration` uses a string such as `"1.5s"` or `"-10s"`.
    private static func durationJSONObject(fromProtoJSONString string: String) throws -> [String: Any] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix("s"), trimmed.count > 1 else {
            throw GrpcClientError.invalidJSON("Invalid google.protobuf.Duration JSON (expected trailing 's')")
        }

        let numericPart = String(trimmed.dropLast())
        guard let secondsValue = Double(numericPart) else {
            throw GrpcClientError.invalidJSON("Invalid google.protobuf.Duration JSON: \(string)")
        }

        let whole = secondsValue >= 0 ? floor(secondsValue) : ceil(secondsValue)
        let sec = Int64(whole)
        let nanos = Int32((secondsValue - Double(sec)) * 1_000_000_000.0)

        return [
            "seconds": NSNumber(value: sec),
            "nanos": NSNumber(value: nanos),
        ]
    }
}
