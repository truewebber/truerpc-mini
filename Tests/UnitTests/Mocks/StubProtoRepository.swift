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

    init(descriptors: [String: MessageDescriptor] = [:], defaultDescriptor: MessageDescriptor? = nil) {
        let fallback: MessageDescriptor? = defaultDescriptor ?? {
            let file = FileDescriptor(name: "stub.proto", package: "stub")
            return MessageDescriptor(name: "Empty", parent: file)
        }()
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
}
