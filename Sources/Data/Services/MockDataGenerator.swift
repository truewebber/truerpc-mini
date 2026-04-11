import Foundation
import SwiftProtoReflect

/// Generates mock JSON for gRPC request bodies from `MessageDescriptor` via `ProtoRepositoryProtocol`.
public final class MockDataGenerator: MockDataGeneratorProtocol, Sendable {
    private let protoRepository: ProtoRepositoryProtocol

    public init(protoRepository: ProtoRepositoryProtocol) {
        self.protoRepository = protoRepository
    }

    public func generate(for messageType: String, in protoFile: ProtoFile) async throws -> String {
        let descriptor = try await protoRepository.getMessageDescriptor(forType: messageType, in: protoFile)

        switch descriptor.fullName {
        case WellKnownTypeNames.timestamp:
            return Self.jsonEncodedString(Self.currentRFC3339Time())

        case WellKnownTypeNames.duration:
            return Self.jsonEncodedString("0s")

        case WellKnownTypeNames.empty:
            return "{}"

        case WellKnownTypeNames.any:
            let object: [String: Any] = [
                "@type": "type.googleapis.com/google.protobuf.Empty",
            ]
            return try Self.jsonEncodedObject(object)

        default:
            let root = try await generateJSONObject(
                for: descriptor,
                protoFile: protoFile,
                pathVisited: [])
            return try Self.jsonEncodedObject(root)
        }
    }

    // MARK: - Private

    private func generateJSONObject(
        for descriptor: MessageDescriptor,
        protoFile: ProtoFile,
        pathVisited: Set<String>)
        async throws -> [String: Any]
    {
        if pathVisited.contains(descriptor.fullName) {
            return [:]
        }

        var nextVisited = pathVisited
        nextVisited.insert(descriptor.fullName)

        var result: [String: Any] = [:]
        let fields = descriptor.allFields()

        var oneofGroups: [Int: [FieldDescriptor]] = [:]
        var nonOneofFields: [FieldDescriptor] = []

        for field in fields {
            if let idx = field.oneofIndex {
                oneofGroups[idx, default: []].append(field)
            } else {
                nonOneofFields.append(field)
            }
        }

        for (_, group) in oneofGroups where !group.isEmpty {
            let chosen = group.randomElement()!
            if let value = try await jsonValue(
                for: chosen,
                protoFile: protoFile,
                pathVisited: nextVisited)
            {
                result[chosen.name] = value
            }
        }

        for field in nonOneofFields {
            if let value = try await jsonValue(
                for: field,
                protoFile: protoFile,
                pathVisited: nextVisited)
            {
                result[field.name] = value
            }
        }

        return result
    }

    private func jsonValue(
        for field: FieldDescriptor,
        protoFile: ProtoFile,
        pathVisited: Set<String>)
        async throws -> Any?
    {
        if field.isMap, let mapInfo = field.mapEntryInfo {
            let keyJSON = mockMapKey(for: mapInfo.keyFieldInfo)
            let valueJSON = try await mockMapValue(
                for: mapInfo.valueFieldInfo,
                protoFile: protoFile,
                pathVisited: pathVisited)
            return [mapKeyString(keyJSON, type: mapInfo.keyFieldInfo.type): valueJSON]
        }

        if field.isRepeated {
            let element = try await scalarOrMessageJSON(
                for: field,
                protoFile: protoFile,
                pathVisited: pathVisited)
            return [element as Any]
        }

        return try await scalarOrMessageJSON(
            for: field,
            protoFile: protoFile,
            pathVisited: pathVisited)
    }

    private func mapKeyString(_ key: Any, type: FieldType) -> String {
        switch type {
        case .bool:
            (key as? Bool).map { $0 ? "true" : "false" } ?? String(describing: key)
        default:
            String(describing: key)
        }
    }

    private func mockMapKey(for keyInfo: KeyFieldInfo) -> Any {
        switch keyInfo.type {
        case .string:
            "key"
        case .bool:
            true
        case .int32, .sint32, .sfixed32:
            Int32(1)
        case .int64, .sint64, .sfixed64:
            Int64(1)
        case .uint32, .fixed32:
            UInt32(1)
        case .uint64, .fixed64:
            UInt64(1)
        default:
            "key"
        }
    }

    private func mockMapValue(
        for valueInfo: ValueFieldInfo,
        protoFile: ProtoFile,
        pathVisited: Set<String>)
        async throws -> Any
    {
        let synthetic = FieldDescriptor(
            name: valueInfo.name,
            number: valueInfo.number,
            type: valueInfo.type,
            typeName: valueInfo.typeName)
        guard
            let any = try await scalarOrMessageJSON(
                for: synthetic,
                protoFile: protoFile,
                pathVisited: pathVisited)
        else {
            throw MockDataGeneratorError.mapValueGenerationFailed
        }

        return any
    }

    private func scalarOrMessageJSON(
        for field: FieldDescriptor,
        protoFile: ProtoFile,
        pathVisited: Set<String>)
        async throws -> Any?
    {
        switch field.type {
        case .double, .float:
            return 0.0

        case .int32, .sint32, .sfixed32:
            return Int32(0)

        case .uint32, .fixed32:
            return UInt32(0)

        // Proto JSON spec encodes int64/uint64 as decimal strings.
        case .int64, .sint64, .sfixed64:
            return "0"

        case .uint64, .fixed64:
            return "0"

        case .bool:
            return false

        case .string:
            return ""

        case .bytes:
            return ""

        case .enum:
            guard let typeName = field.typeName else {
                throw MockDataGeneratorError.missingTypeName(field.name)
            }

            let enumDesc = try await protoRepository.getEnumDescriptor(forType: typeName, in: protoFile)
            let values = enumDesc.allValues()
            // Prefer first non-zero value so the result is a meaningful example; fall back to first.
            let pick = values.first(where: { $0.number != 0 }) ?? values[0]
            return pick.name

        case .message:
            guard let typeName = field.typeName else {
                throw MockDataGeneratorError.missingTypeName(field.name)
            }

            let nested = try await protoRepository.getMessageDescriptor(forType: typeName, in: protoFile)

            switch nested.fullName {
            case WellKnownTypeNames.timestamp:
                return Self.currentRFC3339Time()

            case WellKnownTypeNames.duration:
                return "0s"

            case WellKnownTypeNames.empty:
                return [String: Any]()

            case WellKnownTypeNames.any:
                return [
                    "@type": "type.googleapis.com/google.protobuf.Empty",
                ]

            default:
                break
            }

            if pathVisited.contains(nested.fullName) {
                return [String: Any]()
            }
            return try await generateJSONObject(
                for: nested,
                protoFile: protoFile,
                pathVisited: pathVisited)

        case .group:
            throw MockDataGeneratorError.unsupportedFieldType("group")
        }
    }

    /// Current UTC time formatted as RFC 3339 (e.g. `"2026-04-09T17:44:56Z"`).
    private static func currentRFC3339Time() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    private static func jsonEncodedObject(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            throw MockDataGeneratorError.utf8EncodingFailed
        }

        return string
    }

    private static func jsonEncodedString(_ value: String) -> String {
        var out = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"":
                out += "\\\""
            case "\\":
                out += "\\\\"
            case "\u{8}":
                out += "\\b"
            case "\u{c}":
                out += "\\f"
            case "\n":
                out += "\\n"
            case "\r":
                out += "\\r"
            case "\t":
                out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out += "\""
        return out
    }
}

// MARK: - Errors

enum MockDataGeneratorError: Error, Equatable {
    case utf8EncodingFailed
    case missingTypeName(String)
    case mapValueGenerationFailed
    case unsupportedFieldType(String)
}

extension MockDataGeneratorError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .utf8EncodingFailed:
            "Failed to encode generated JSON as UTF-8"
        case let .missingTypeName(fieldName):
            "Missing type name for message field '\(fieldName)'"
        case .mapValueGenerationFailed:
            "Failed to generate mock value for map entry"
        case let .unsupportedFieldType(type):
            "Unsupported field type '\(type)'"
        }
    }
}
