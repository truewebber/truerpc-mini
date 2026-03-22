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
            return Self.jsonEncodedString("2006-01-02T15:04:05Z")

        case WellKnownTypeNames.duration:
            return Self.jsonEncodedString("1.5s")

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
                parent: descriptor,
                protoFile: protoFile,
                pathVisited: nextVisited)
            {
                result[chosen.jsonName] = value
            }
        }

        for field in nonOneofFields {
            if let value = try await jsonValue(
                for: field,
                parent: descriptor,
                protoFile: protoFile,
                pathVisited: nextVisited)
            {
                result[field.jsonName] = value
            }
        }

        return result
    }

    private func jsonValue(
        for field: FieldDescriptor,
        parent: MessageDescriptor,
        protoFile: ProtoFile,
        pathVisited: Set<String>)
        async throws -> Any?
    {
        if field.isMap, let mapInfo = field.mapEntryInfo {
            let keyJSON = mockMapKey(for: mapInfo.keyFieldInfo)
            let valueJSON = try await mockMapValue(
                for: mapInfo.valueFieldInfo,
                parent: parent,
                protoFile: protoFile,
                pathVisited: pathVisited)
            return [mapKeyString(keyJSON, type: mapInfo.keyFieldInfo.type): valueJSON]
        }

        if field.isRepeated {
            let element = try await scalarOrMessageJSON(
                for: field,
                parent: parent,
                protoFile: protoFile,
                pathVisited: pathVisited)
            return [element as Any]
        }

        return try await scalarOrMessageJSON(
            for: field,
            parent: parent,
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
        parent: MessageDescriptor,
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
                parent: parent,
                protoFile: protoFile,
                pathVisited: pathVisited)
        else {
            throw MockDataGeneratorError.mapValueGenerationFailed
        }

        return any
    }

    private func scalarOrMessageJSON(
        for field: FieldDescriptor,
        parent: MessageDescriptor,
        protoFile: ProtoFile,
        pathVisited: Set<String>)
        async throws -> Any?
    {
        switch field.type {
        case .double:
            return Double.random(in: -1000 ... 1000)

        case .float:
            return Float.random(in: -100 ... 100)

        case .int32, .sint32, .sfixed32:
            return Int32.random(in: -100 ... 100)

        case .uint32, .fixed32:
            return UInt32.random(in: 0 ... 100)

        case .int64, .sint64, .sfixed64:
            return String(Int64.random(in: -1000 ... 1000))

        case .uint64, .fixed64:
            return String(UInt64.random(in: 0 ... 1000))

        case .bool:
            return Bool.random()

        case .string:
            return "Lorem ipsum dolor sit amet"

        case .bytes:
            var bytes = [UInt8](repeating: 0, count: 4)
            for i in bytes.indices {
                bytes[i] = UInt8.random(in: 0 ... 255)
            }
            return Data(bytes).base64EncodedString()

        case .enum:
            guard let enumDesc = resolveEnumDescriptor(field: field, parent: parent) else {
                throw MockDataGeneratorError.enumDescriptorNotFound(field.typeName ?? "")
            }

            let values = enumDesc.allValues()
            let candidates = values.filter { $0.number != 0 }
            let pick = candidates.randomElement() ?? values.randomElement()!
            return Int(pick.number)

        case .message:
            guard let typeName = field.typeName else {
                throw MockDataGeneratorError.missingTypeName(field.name)
            }

            let nested = try await protoRepository.getMessageDescriptor(forType: typeName, in: protoFile)

            switch nested.fullName {
            case WellKnownTypeNames.timestamp:
                return "2006-01-02T15:04:05Z"

            case WellKnownTypeNames.duration:
                return "1.5s"

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

    private func resolveEnumDescriptor(field: FieldDescriptor, parent: MessageDescriptor) -> EnumDescriptor? {
        guard let raw = field.typeName else { return nil }

        let trimmed = raw.hasPrefix(".") ? String(raw.dropFirst()) : raw
        let simple = simpleTypeName(from: trimmed)
        return parent.nestedEnum(named: simple)
    }

    private func simpleTypeName(from fullName: String) -> String {
        if let last = fullName.split(separator: ".").last {
            return String(last)
        }
        return fullName
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
    case enumDescriptorNotFound(String)
    case mapValueGenerationFailed
    case unsupportedFieldType(String)
}
