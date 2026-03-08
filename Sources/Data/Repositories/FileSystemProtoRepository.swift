import Foundation
import SwiftProtobuf
import SwiftProtoParser
import SwiftProtoReflect

// MARK: - ProtoParseError helpers

private extension Error {
    /// Extracts unresolved import information from a dependency resolution error.
    ///
    /// Returns the resolver's error description, which contains the missing import path.
    var missingImport: String? {
        guard let parseError = self as? ProtoParseError else { return nil }

        if case let .dependencyResolutionError(message, _) = parseError {
            return message
        }
        return nil
    }
}

/// Repository for loading proto files from the file system
/// Implements ProtoRepositoryProtocol from Domain layer
public final class FileSystemProtoRepository: ProtoRepositoryProtocol {
    private var loadedProtos: [ProtoFile] = []
    private var fileDescriptors: [Google_Protobuf_FileDescriptorProto] = []
    private let logger: AppLogger
    /// Path prefix for well-known bundled types; dependencies resolved under this prefix are excluded from
    /// `ProtoFile.dependencyPaths` because they are read-only and do not need to be watched.
    private let wellKnownResourcePath: String?

    public init(logger: AppLogger, wellKnownResourcePath: String? = Bundle.main.resourcePath) {
        self.logger = logger
        self.wellKnownResourcePath = wellKnownResourcePath
    }

    public func loadProto(url: URL) throws -> ProtoFile {
        try loadProto(url: url, importPaths: [])
    }

    public func loadProto(url: URL, importPaths: [String]) throws -> ProtoFile {
        // parseFile returns a FileDescriptorSet with all transitive dependencies in
        // topological order (dependencies first, requested file last).
        let result = SwiftProtoParser.parseFile(url.path, importPaths: importPaths)

        switch result {
        case let .success(descriptorSet):
            // Store ALL descriptors (main + transitive deps), upserted by filename so that
            // re-loading a modified file replaces the stale descriptor in the registry.
            for descriptor in descriptorSet.file {
                if let idx = fileDescriptors.firstIndex(where: { $0.name == descriptor.name }) {
                    fileDescriptors[idx] = descriptor
                } else {
                    fileDescriptors.append(descriptor)
                }
            }

            // The main file is identifiable by filename; topological order places it
            // last, so fall back to the last element if the name match fails.
            let mainFileName = url.lastPathComponent
            guard let mainDescriptor =
                descriptorSet.file.last(where: { $0.name == mainFileName })
                    ?? descriptorSet.file.last
            else {
                throw ProtoRepositoryError.parsingFailed("No descriptor returned for \(mainFileName)")
            }

            let depPaths = resolveDependencyPaths(
                descriptorSet: descriptorSet,
                rootURL: url,
                importPaths: importPaths)
            let protoFile = mapToProtoFile(
                fileDescriptor: mainDescriptor,
                url: url,
                dependencyPaths: depPaths)
            loadedProtos.append(protoFile)
            return protoFile

        case let .failure(error):
            logger.error("Proto parsing failed", metadata: [
                "file": url.lastPathComponent,
                "error": error.localizedDescription,
                "dependencies_count": String(importPaths.count),
                "missing_imports": error.missingImport ?? "",
            ])
            throw ProtoRepositoryError.parsingFailed(error.localizedDescription)
        }
    }

    public func getLoadedProtos() -> [ProtoFile] {
        loadedProtos
    }

    public func getMessageDescriptor(forType typeName: String) throws -> MessageDescriptor {
        // Normalize type name - remove leading dot if present
        let normalizedTypeName = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName

        // Search through all loaded file descriptors
        for fileDescriptor in fileDescriptors {
            // Try exact match first
            if let descriptor = try? findMessageDescriptor(
                in: fileDescriptor,
                typeName: normalizedTypeName,
                package: fileDescriptor.package)
            {
                return descriptor
            }
        }

        throw ProtoRepositoryError.messageTypeNotFound(typeName)
    }

    // MARK: - Private Helpers

    /// Recursively find message descriptor by type name
    private func findMessageDescriptor(
        in fileDescriptor: Google_Protobuf_FileDescriptorProto,
        typeName: String,
        package: String)
        throws -> MessageDescriptor?
    {
        // Build fully qualified name prefix
        let packagePrefix = package.isEmpty ? "" : "\(package)."

        // Search through messages in file descriptor
        for messageType in fileDescriptor.messageType {
            let fullName = packagePrefix + messageType.name

            if fullName == typeName || messageType.name == typeName {
                // Found it! Convert to SwiftProtoReflect MessageDescriptor
                return try convertToMessageDescriptor(messageType, package: package)
            }

            // Search in nested types
            if let nested = try findNestedMessageDescriptor(
                in: messageType,
                typeName: typeName,
                parentName: fullName)
            {
                return nested
            }
        }

        return nil
    }

    /// Find message descriptor in nested types
    private func findNestedMessageDescriptor(
        in messageType: Google_Protobuf_DescriptorProto,
        typeName: String,
        parentName: String)
        throws -> MessageDescriptor?
    {
        for nestedType in messageType.nestedType {
            let fullName = "\(parentName).\(nestedType.name)"

            if fullName == typeName || nestedType.name == typeName {
                return try convertToMessageDescriptor(nestedType, package: parentName)
            }

            // Recurse deeper
            if let deeper = try findNestedMessageDescriptor(
                in: nestedType,
                typeName: typeName,
                parentName: fullName)
            {
                return deeper
            }
        }

        return nil
    }

    /// Convert Google_Protobuf_DescriptorProto to SwiftProtoReflect MessageDescriptor
    private func convertToMessageDescriptor(
        _ protoDescriptor: Google_Protobuf_DescriptorProto,
        package: String)
        throws -> MessageDescriptor
    {
        // Create file descriptor for SwiftProtoReflect
        let fileDesc = FileDescriptor(
            name: "dynamic.proto",
            package: package)

        // Create message descriptor
        var messageDesc = MessageDescriptor(
            name: protoDescriptor.name,
            parent: fileDesc)

        // Add fields
        for field in protoDescriptor.field {
            let fieldDesc = try convertToFieldDescriptor(field)
            messageDesc.addField(fieldDesc)
        }

        return messageDesc
    }

    /// Convert Google_Protobuf_FieldDescriptorProto to SwiftProtoReflect FieldDescriptor
    private func convertToFieldDescriptor(
        _ fieldProto: Google_Protobuf_FieldDescriptorProto)
        throws -> FieldDescriptor
    {
        let fieldType = convertFieldType(fieldProto.type)

        // Check if field is repeated
        let isRepeated = fieldProto.label == .repeated

        // For message and enum types, we need to provide the typeName
        if fieldType == .message || fieldType == .enum {
            let typeName = fieldProto.typeName.hasPrefix(".")
                ? String(fieldProto.typeName.dropFirst())
                : fieldProto.typeName

            return FieldDescriptor(
                name: fieldProto.name,
                number: Int(fieldProto.number),
                type: fieldType,
                typeName: typeName,
                isRepeated: isRepeated)
        }

        return FieldDescriptor(
            name: fieldProto.name,
            number: Int(fieldProto.number),
            type: fieldType,
            isRepeated: isRepeated)
    }

    /// Convert protobuf field type to SwiftProtoReflect FieldType
    private func convertFieldType(_ type: Google_Protobuf_FieldDescriptorProto.TypeEnum) -> SwiftProtoReflect
        .FieldType
    {
        switch type {
        case .double: return .double
        case .float: return .float
        case .int64: return .int64
        case .uint64: return .uint64
        case .int32: return .int32
        case .fixed64: return .fixed64
        case .fixed32: return .fixed32
        case .bool: return .bool
        case .string: return .string
        case .group: return .message // Treat group as message
        case .message: return .message
        case .bytes: return .bytes
        case .uint32: return .uint32
        case .enum: return .enum
        case .sfixed32: return .sfixed32
        case .sfixed64: return .sfixed64
        case .sint32: return .sint32
        case .sint64: return .sint64
        @unknown default: return .string // Fallback
        }
    }

    /// Resolves transitive dependency paths from `descriptorSet` to absolute file URLs.
    /// `descriptor.name` is the import-relative path (e.g. `"common/types.proto"`); the root file's
    /// descriptor has just a bare filename and resolves to nil, so it is excluded automatically.
    /// Paths under `wellKnownResourcePath` are also excluded.
    private func resolveDependencyPaths(
        descriptorSet: Google_Protobuf_FileDescriptorSet,
        rootURL: URL,
        importPaths: [String])
        -> [URL]
    {
        descriptorSet.file.compactMap { descriptor -> URL? in
            guard let url = resolveImportString(descriptor.name, importPaths: importPaths) else { return nil }

            return url.standardized == rootURL.standardized ? nil : url
        }
    }

    /// Resolves a proto import string (e.g. `"common/types.proto"`) to an absolute file URL.
    /// Returns nil if the file cannot be found or falls under `wellKnownResourcePath`.
    private func resolveImportString(_ importString: String, importPaths: [String]) -> URL? {
        for importPath in importPaths {
            let candidate = URL(fileURLWithPath: importPath).appendingPathComponent(importString)
            guard FileManager.default.fileExists(atPath: candidate.path) else { continue }

            if let wellKnown = wellKnownResourcePath, candidate.path.hasPrefix(wellKnown) { return nil }
            return candidate
        }
        return nil
    }

    // MARK: - Private Mapping

    private func mapToProtoFile(
        fileDescriptor: Google_Protobuf_FileDescriptorProto,
        url: URL,
        dependencyPaths: [URL] = [])
        -> ProtoFile
    {
        let services = fileDescriptor.service.map { serviceDesc in
            mapToService(serviceDescriptor: serviceDesc, package: fileDescriptor.package)
        }

        return ProtoFile(
            name: url.lastPathComponent,
            path: url,
            services: services,
            dependencyPaths: dependencyPaths)
    }

    private func mapToService(
        serviceDescriptor: Google_Protobuf_ServiceDescriptorProto,
        package: String)
        -> Service
    {
        // Construct fully qualified service name: package.ServiceName
        let fullServiceName = package.isEmpty ? serviceDescriptor.name : "\(package).\(serviceDescriptor.name)"

        let methods = serviceDescriptor.method.map { methodDesc in
            mapToMethod(methodDescriptor: methodDesc, serviceName: fullServiceName)
        }

        return Service(
            name: serviceDescriptor.name,
            methods: methods)
    }

    private func mapToMethod(
        methodDescriptor: Google_Protobuf_MethodDescriptorProto,
        serviceName: String)
        -> Method
    {
        Method(
            name: methodDescriptor.name,
            serviceName: serviceName,
            inputType: methodDescriptor.inputType,
            outputType: methodDescriptor.outputType,
            isStreaming: methodDescriptor.clientStreaming || methodDescriptor.serverStreaming)
    }
}

// MARK: - Error Types

public enum ProtoRepositoryError: Error, Equatable {
    case parsingFailed(String)
    case fileNotFound
    case messageTypeNotFound(String)
}

extension ProtoRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .parsingFailed(message):
            "Failed to parse proto file: \(message)"
        case .fileNotFound:
            "Proto file not found"
        case let .messageTypeNotFound(typeName):
            "Message type '\(typeName)' not found in loaded proto files"
        }
    }
}
