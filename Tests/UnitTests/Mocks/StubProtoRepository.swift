import Foundation
import os
import SwiftProtoReflect
@testable import TrueRPCMini

/// Test double for `ProtoRepositoryProtocol` that resolves message types from an in-memory map.
final class StubProtoRepository: ProtoRepositoryProtocol, Sendable {
    private struct State {
        var descriptors: [String: MessageDescriptor] = [:]
        var defaultDescriptor: MessageDescriptor?
    }

    private let storage = OSAllocatedUnfairLock(initialState: State())

    /// - Parameters:
    ///   - descriptors: Explicit type-name → descriptor map.
    ///   - defaultDescriptor: Fallback descriptor returned when type is not in the map.
    ///     Pass `nil` **and** `useFallback: false` to make all unknown lookups throw.
    ///   - useFallback: When `true` (default) and `defaultDescriptor` is nil, an empty
    ///     `"stub.Empty"` descriptor is created automatically. Set to `false` to disable.
    init(
        descriptors: [String: MessageDescriptor] = [:],
        defaultDescriptor: MessageDescriptor? = nil,
        useFallback: Bool = true)
    {
        let fallback: MessageDescriptor? = defaultDescriptor ?? (useFallback ? {
            let file = FileDescriptor(name: "stub.proto", package: "stub")
            return MessageDescriptor(name: "Empty", parent: file)
        }() : nil)
        storage.withLock {
            $0.descriptors = descriptors
            $0.defaultDescriptor = fallback
        }
    }

    func loadProto(url: URL) throws -> ProtoFile {
        ProtoFile(name: url.lastPathComponent, path: url, services: [])
    }

    func loadProto(url: URL, importPaths _: [String]) throws -> ProtoFile {
        ProtoFile(name: url.lastPathComponent, path: url, services: [])
    }

    func getLoadedProtos() -> [ProtoFile] {
        []
    }

    func getMessageDescriptor(forType typeName: String, in _: ProtoFile) throws -> MessageDescriptor {
        let trimmed = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName
        let resolved: MessageDescriptor? = storage.withLock { state in
            if let hit = state.descriptors[typeName] {
                return hit
            }
            if let hit = state.descriptors[trimmed] {
                return hit
            }
            return state.defaultDescriptor
        }
        guard let descriptor = resolved else {
            throw ProtoRepositoryError.messageTypeNotFound(typeName)
        }

        return descriptor
    }

    func makeJSONTypeRegistry(for _: ProtoFile) throws -> TypeRegistry {
        let registry = TypeRegistry()
        let descriptors = storage.withLock { Array($0.descriptors.values) }
        for descriptor in descriptors {
            try? registry.registerMessage(descriptor)
        }
        if let fallback = storage.withLock({ $0.defaultDescriptor }) {
            try? registry.registerMessage(fallback)
        }
        return registry
    }
}
