import Foundation
import SwiftProtoReflect

/// Derives JSON body autocomplete suggestions by traversing the proto schema
/// for the message type in scope at the given `AutocompleteContext`.
public final class ProtoSchemaAutocompleteProvider: AutocompleteProviderProtocol, Sendable {
    private let protoRepository: ProtoRepositoryProtocol

    public init(protoRepository: ProtoRepositoryProtocol) {
        self.protoRepository = protoRepository
    }

    public func suggestions(
        for context: AutocompleteContext,
        rootMessageType: String,
        in protoFile: ProtoFile)
        async -> [AutocompleteSuggestion]
    {
        guard let rootDescriptor = try? await protoRepository.getMessageDescriptor(
            forType: rootMessageType,
            in: protoFile)
        else { return [] }

        switch context.mode {
        case .key:
            return await keyModeSuggestions(
                path: context.resolvedPath,
                rootDescriptor: rootDescriptor,
                protoFile: protoFile)

        case .enumValue:
            return await enumValueModeSuggestions(
                path: context.resolvedPath,
                currentFieldKey: context.currentFieldKey,
                rootDescriptor: rootDescriptor,
                protoFile: protoFile)

        case .arrayElement:
            return await arrayElementModeSuggestions(
                path: context.resolvedPath,
                rootDescriptor: rootDescriptor,
                protoFile: protoFile)
        }
    }

    // MARK: - Mode handlers

    private func keyModeSuggestions(
        path: [String],
        rootDescriptor: MessageDescriptor,
        protoFile: ProtoFile)
        async -> [AutocompleteSuggestion]
    {
        guard let descriptor = await navigate(from: rootDescriptor, path: path, protoFile: protoFile) else { return [] }

        return fieldSuggestions(for: descriptor)
    }

    private func enumValueModeSuggestions(
        path: [String],
        currentFieldKey: String?,
        rootDescriptor: MessageDescriptor,
        protoFile: ProtoFile)
        async -> [AutocompleteSuggestion]
    {
        // When `currentFieldKey` is provided by the resolver, `path` is the path to the current
        // object and `currentFieldKey` is the field being edited.
        // Legacy callers (e.g. tests) may pass `currentFieldKey: nil` with the field name as
        // `path.last` and parent path as `path.dropLast()`.
        let fieldName: String
        let parentPath: [String]
        if let key = currentFieldKey {
            fieldName = key
            parentPath = path
        } else {
            guard let last = path.last else { return [] }

            fieldName = last
            parentPath = Array(path.dropLast())
        }

        guard let parent = await navigate(from: rootDescriptor, path: parentPath, protoFile: protoFile)
        else { return [] }
        guard let field = parent.field(named: fieldName),
              field.type == .enum,
              let typeName = field.typeName
        else { return [] }
        guard let enumDescriptor = await resolveEnumDescriptor(typeName: typeName, in: parent, protoFile: protoFile)
        else { return [] }

        return enumValueSuggestions(from: enumDescriptor, typeName: typeName)
    }

    private func arrayElementModeSuggestions(
        path: [String],
        rootDescriptor: MessageDescriptor,
        protoFile: ProtoFile)
        async -> [AutocompleteSuggestion]
    {
        guard let fieldName = path.last else { return [] }

        let parentPath = Array(path.dropLast())

        guard let parent = await navigate(from: rootDescriptor, path: parentPath, protoFile: protoFile)
        else { return [] }
        guard let field = parent.field(named: fieldName) else { return [] }

        switch field.type {
        case .message:
            guard let typeName = field.typeName,
                  !isWellKnownStringType(typeName),
                  let elementDescriptor = try? await protoRepository.getMessageDescriptor(
                      forType: typeName,
                      in: protoFile)
            else { return [] }

            return fieldSuggestions(for: elementDescriptor)

        case .enum:
            guard let typeName = field.typeName,
                  let enumDescriptor = await resolveEnumDescriptor(typeName: typeName, in: parent, protoFile: protoFile)
            else { return [] }

            return enumValueSuggestions(from: enumDescriptor, typeName: typeName)

        default:
            return []
        }
    }

    // MARK: - Suggestion builders

    private func fieldSuggestions(for descriptor: MessageDescriptor) -> [AutocompleteSuggestion] {
        var result: [AutocompleteSuggestion] = [
            AutocompleteSuggestion(name: "fillDefaults", typeHint: "", kind: .fillDefaults),
        ]

        for field in descriptor.allFields() {
            let oneOfGroup = field.oneofIndex.flatMap { descriptor.oneof(at: $0)?.name }
            result.append(AutocompleteSuggestion(
                name: field.name,
                typeHint: typeHint(for: field),
                kind: kind(for: field),
                oneOfGroup: oneOfGroup))
        }

        return result
    }

    private func enumValueSuggestions(from descriptor: EnumDescriptor, typeName: String) -> [AutocompleteSuggestion] {
        descriptor.allValues().map { value in
            AutocompleteSuggestion(
                name: value.name,
                typeHint: simpleTypeName(from: typeName),
                kind: .enum)
        }
    }

    // MARK: - Schema navigation

    private func navigate(
        from descriptor: MessageDescriptor,
        path: [String],
        protoFile: ProtoFile)
        async -> MessageDescriptor?
    {
        var current = descriptor
        for segment in path {
            guard let field = current.field(named: segment),
                  field.type == .message,
                  let typeName = field.typeName,
                  let next = try? await protoRepository.getMessageDescriptor(forType: typeName, in: protoFile)
            else { return nil }

            current = next
        }
        return current
    }

    /// Resolves an enum descriptor by first checking nested enums on `parent`, then falling back
    /// to the repository for top-level / externally-defined enums.
    private func resolveEnumDescriptor(
        typeName: String,
        in parent: MessageDescriptor,
        protoFile: ProtoFile)
        async -> EnumDescriptor?
    {
        let trimmed = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName
        if let nested = parent.nestedEnum(named: simpleTypeName(from: trimmed)) { return nested }
        return try? await protoRepository.getEnumDescriptor(forType: trimmed, in: protoFile)
    }

    // MARK: - Type helpers

    private func kind(for field: FieldDescriptor) -> SuggestionKind {
        if field.isRepeated {
            return .repeated
        }
        switch field.type {
        case .string, .bytes:
            return .string

        case .double, .float,
             .int32, .int64, .uint32, .uint64,
             .sint32, .sint64, .fixed32, .fixed64, .sfixed32, .sfixed64:
            return .number

        case .bool:
            return .bool

        case .message:
            if isWellKnownStringType(field.typeName) { return .string }
            return .message

        case .enum:
            return .enumField

        case .group:
            return .string
        }
    }

    private func typeHint(for field: FieldDescriptor) -> String {
        let base = scalarTypeHint(for: field)
        return field.isRepeated && !field.isMap ? base + "[]" : base
    }

    private func scalarTypeHint(for field: FieldDescriptor) -> String {
        switch field.type {
        case .double: "double"
        case .float: "float"
        case .int32, .sint32, .sfixed32: "int32"
        case .int64, .sint64, .sfixed64: "int64"
        case .uint32, .fixed32: "uint32"
        case .uint64, .fixed64: "uint64"
        case .bool: "bool"
        case .string: "string"
        case .bytes: "bytes"
        case .message, .enum: simpleTypeName(from: field.typeName ?? "")
        case .group: "group"
        }
    }

    /// Returns `true` when `typeName` refers to a WKT whose JSON representation is a plain string
    /// (`google.protobuf.Timestamp` → RFC 3339, `google.protobuf.Duration` → `"1.5s"`).
    private func isWellKnownStringType(_ typeName: String?) -> Bool {
        guard let typeName else { return false }

        let normalized = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName
        return normalized == WellKnownTypeNames.timestamp || normalized == WellKnownTypeNames.duration
    }

    private func simpleTypeName(from fullName: String) -> String {
        guard let last = fullName.split(separator: ".").last else { return fullName }

        return String(last)
    }
}
