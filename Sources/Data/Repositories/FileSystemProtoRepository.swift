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

/// Repository for loading proto files from the file system.
/// Implements ProtoRepositoryProtocol from Domain layer.
///
/// All `Google_Protobuf_FileDescriptorProto` values parsed by SwiftProtoParser are
/// converted to `SwiftProtoReflect.FileDescriptor` via `DescriptorBridge` and registered
/// in a `DescriptorPool`. Lookup methods (`getMessageDescriptor`, `getEnumDescriptor`)
/// delegate entirely to the pool; scope-checking is done via `fileDescriptorPath` on
/// each returned descriptor.
public actor FileSystemProtoRepository: ProtoRepositoryProtocol {
    private var loadedProtos: [ProtoFile] = []

    /// Raw descriptors retained for scope resolution (main file + transitive deps per tab).
    private var rawFileDescriptors: [Google_Protobuf_FileDescriptorProto] = []

    /// Pool rebuilt from `rawFileDescriptors` whenever a proto file is loaded.
    private var pool: DescriptorPool = .init(includeBuiltinDescriptors: true)

    /// Bridged `FileDescriptor` objects keyed by file name, used as fallback when the
    /// pool cannot resolve a type (e.g. duplicate unqualified names across files or
    /// nested enums whose `fullName` was not propagated correctly by `DescriptorBridge`).
    private var bridgedFileDescriptors: [String: FileDescriptor] = [:]

    private let bridge = DescriptorBridge()
    private let logger: AppLogger

    /// Path prefix for well-known bundled types; dependencies resolved under this prefix are excluded from
    /// `ProtoFile.dependencyPaths` because they are read-only and do not need to be watched.
    private let wellKnownResourcePath: String?

    public init(logger: AppLogger, wellKnownResourcePath: String? = Bundle.main.resourcePath) {
        self.logger = logger
        self.wellKnownResourcePath = wellKnownResourcePath
    }

    public func loadProto(url: URL) async throws -> ProtoFile {
        try await loadProto(url: url, importPaths: [])
    }

    public func loadProto(url: URL, importPaths: [String]) async throws -> ProtoFile {
        // parseFile returns a FileDescriptorSet with all transitive dependencies in
        // topological order (dependencies first, requested file last).
        let result = SwiftProtoParser.parseFile(url.path, importPaths: importPaths)

        switch result {
        case let .success(descriptorSet):
            // Upsert raw descriptors so that re-loading a modified file replaces stale data.
            for descriptor in descriptorSet.file {
                if let idx = rawFileDescriptors.firstIndex(where: { $0.name == descriptor.name }) {
                    rawFileDescriptors[idx] = descriptor
                } else {
                    rawFileDescriptors.append(descriptor)
                }
            }

            await rebuildPool()

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
                "error": "\(error)",
                "dependencies_count": String(importPaths.count),
                "missing_imports": error.missingImport ?? "",
            ])
            throw ProtoRepositoryError.parsingFailed(error.localizedDescription)
        }
    }

    public func getLoadedProtos() -> [ProtoFile] {
        loadedProtos
    }

    public func getMessageDescriptor(
        forType typeName: String,
        in protoFile: ProtoFile)
        async throws -> MessageDescriptor
    {
        let normalized = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName

        let poolResult = await pool.findMessageDescriptor(named: normalized)
        if let descriptor = poolResult,
           isFileInScope(descriptor.fileDescriptorPath, protoFile: protoFile)
        {
            return descriptor
        }

        // Fallback: scan bridged file descriptors in scope (handles files with duplicate
        // unqualified names when the pool silently dropped one due to duplicateSymbol).
        if let descriptor = findMessageInScopedFiles(named: normalized, protoFile: protoFile) {
            return descriptor
        }

        throw ProtoRepositoryError.messageTypeNotFound(typeName)
    }

    public func getEnumDescriptor(forType typeName: String, in protoFile: ProtoFile) async throws -> EnumDescriptor {
        let normalized = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName

        let poolEnumResult = await pool.findEnumDescriptor(named: normalized)
        if let descriptor = poolEnumResult,
           isFileInScope(descriptor.fileDescriptorPath, protoFile: protoFile)
        {
            return descriptor
        }

        // Fallback 1: scan top-level enums in bridged file descriptors in scope.
        if let descriptor = findEnumInScopedFiles(named: normalized, protoFile: protoFile) {
            return descriptor
        }

        // Fallback 2: nested enum lookup — DescriptorBridge may not propagate fullName into
        // nested EnumDescriptors, so they land in the pool under just their simple name.
        // Decompose "pkg.Message.EnumName" → find message "pkg.Message" then nestedEnum("EnumName").
        if let descriptor = await findNestedEnumByPath(named: normalized, protoFile: protoFile) {
            return descriptor
        }

        throw ProtoRepositoryError.enumTypeNotFound(typeName)
    }

    public func makeJSONTypeRegistry(for protoFile: ProtoFile) async throws -> TypeRegistry {
        let registry = TypeRegistry()
        for (_, fileDesc) in bridgedFileDescriptors {
            guard isFileInScope(fileDesc.name, protoFile: protoFile) else { continue }

            try? await registry.registerFile(fileDesc)
        }
        return registry
    }

    // MARK: - Private: Pool

    /// Rebuilds the `DescriptorPool` and the `bridgedFileDescriptors` cache from scratch.
    ///
    /// Called after every successful `loadProto`. `DescriptorBridge` handles the full
    /// conversion of each `Google_Protobuf_FileDescriptorProto` — including top-level enums,
    /// nested enums, nested messages, oneofs, and map entries — into `SwiftProtoReflect` types.
    ///
    /// `try?` on `addFileDescriptor` intentionally ignores `duplicateFile` / `duplicateSymbol`
    /// for google/protobuf well-known types that are already registered by the built-in pool.
    /// `bridgedFileDescriptors` retains every converted `FileDescriptor` so that fallback lookups
    /// in `getMessageDescriptor` / `getEnumDescriptor` can still find types the pool silently dropped.
    private func rebuildPool() async {
        let newPool = DescriptorPool(includeBuiltinDescriptors: true)
        var newBridged: [String: FileDescriptor] = [:]
        for raw in rawFileDescriptors {
            guard let fd = try? bridge.fromProtobufFileDescriptor(raw) else { continue }

            newBridged[fd.name] = fd
            try? await newPool.addFileDescriptor(fd)
        }
        pool = newPool
        bridgedFileDescriptors = newBridged
    }

    // MARK: - Private: Fallback descriptor search

    private func findMessageInScopedFiles(named typeName: String, protoFile: ProtoFile) -> MessageDescriptor? {
        for (_, fileDesc) in bridgedFileDescriptors {
            guard isFileInScope(fileDesc.name, protoFile: protoFile) else { continue }

            if let msg = findMessage(in: fileDesc, named: typeName) { return msg }
        }
        return nil
    }

    private func findMessage(in fileDesc: FileDescriptor, named typeName: String) -> MessageDescriptor? {
        for (_, msg) in fileDesc.messages {
            if msg.fullName == typeName { return msg }
            if let found = findNestedMessage(in: msg, named: typeName) { return found }
        }
        return nil
    }

    private func findNestedMessage(in msg: MessageDescriptor, named typeName: String) -> MessageDescriptor? {
        for (_, nested) in msg.nestedMessages {
            if nested.fullName == typeName { return nested }
            if let deep = findNestedMessage(in: nested, named: typeName) { return deep }
        }
        return nil
    }

    private func findEnumInScopedFiles(named typeName: String, protoFile: ProtoFile) -> EnumDescriptor? {
        for (_, fileDesc) in bridgedFileDescriptors {
            guard isFileInScope(fileDesc.name, protoFile: protoFile) else { continue }

            for (_, enumDesc) in fileDesc.enums {
                if enumDesc.fullName == typeName { return enumDesc }
            }
        }
        return nil
    }

    /// Handles nested enums whose `fullName` was not propagated by `DescriptorBridge`.
    ///
    /// For `"myapp.Response.Code"` this tries progressively shorter parent paths:
    ///   parent `"myapp.Response"` → `nestedEnum(named: "Code")`.
    private func findNestedEnumByPath(named typeName: String, protoFile: ProtoFile) async -> EnumDescriptor? {
        let components = typeName.split(separator: ".").map(String.init)
        guard components.count >= 2 else { return nil }

        let enumName = components.last!
        for prefixLen in stride(from: components.count - 1, through: 1, by: -1) {
            let parentName = components.prefix(prefixLen).joined(separator: ".")

            let fromPoolResult = await pool.findMessageDescriptor(named: parentName)
            let parentMsg: MessageDescriptor? = if let fromPool = fromPoolResult, isFileInScope(
                fromPool.fileDescriptorPath,
                protoFile: protoFile)
            {
                fromPool
            } else {
                findMessageInScopedFiles(named: parentName, protoFile: protoFile)
            }

            if let msg = parentMsg, let enumDesc = msg.nestedEnum(named: enumName) {
                return enumDesc
            }
        }
        return nil
    }

    // MARK: - Private: Scope

    /// File names allowed for descriptor lookup for `protoFile` (main file + dependency basenames).
    private func allowedDescriptorBasenames(for protoFile: ProtoFile) -> Set<String> {
        var names = Set<String>()
        names.insert(protoFile.path.lastPathComponent)
        for url in protoFile.dependencyPaths {
            names.insert(url.lastPathComponent)
        }
        return names
    }

    /// Returns `true` when `filePath` belongs to a file that is in scope for `protoFile`.
    ///
    /// `nil` path means the descriptor was synthesised (e.g. built-in WKT) and is always in scope.
    /// `google/protobuf/` prefixed paths are always in scope (well-known types).
    private func isFileInScope(_ filePath: String?, protoFile: ProtoFile) -> Bool {
        guard let path = filePath else { return true }

        if path.hasPrefix("google/protobuf/") { return true }
        let allowed = allowedDescriptorBasenames(for: protoFile)
        let lastComponent = (path as NSString).lastPathComponent
        return allowed.contains(path) || allowed.contains(lastComponent)
    }

    // MARK: - Private: Dependency resolution

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

    // MARK: - Private: Mapping

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
        let fullServiceName = package.isEmpty ? serviceDescriptor.name : "\(package).\(serviceDescriptor.name)"
        let methods = serviceDescriptor.method.map { methodDesc in
            mapToMethod(methodDescriptor: methodDesc, serviceName: fullServiceName)
        }
        return Service(name: serviceDescriptor.name, methods: methods)
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
    case enumTypeNotFound(String)
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
        case let .enumTypeNotFound(typeName):
            "Enum type '\(typeName)' not found in loaded proto files"
        }
    }
}
