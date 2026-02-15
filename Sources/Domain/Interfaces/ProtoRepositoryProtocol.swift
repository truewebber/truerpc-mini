import Foundation
import SwiftProtoReflect

/// Protocol defining the contract for proto file repository
/// Follows Dependency Inversion Principle - Domain defines the interface
public protocol ProtoRepositoryProtocol {
    /// Loads and parses a proto file from the given URL without import path resolution
    /// - Parameter url: File URL pointing to a .proto file
    /// - Returns: Parsed ProtoFile entity
    /// - Throws: Error if file cannot be read or parsed
    /// - Note: This method does not resolve import statements. Use loadProto(url:importPaths:) for files with dependencies.
    func loadProto(url: URL) async throws -> ProtoFile
    
    /// Loads and parses a proto file with import path resolution
    /// - Parameters:
    ///   - url: File URL pointing to a .proto file
    ///   - importPaths: Array of directory paths to search for imported proto files
    /// - Returns: Parsed ProtoFile entity with resolved dependencies
    /// - Throws: Error if file cannot be read, parsed, or dependencies cannot be resolved
    func loadProto(url: URL, importPaths: [String]) async throws -> ProtoFile
    
    /// Returns all currently loaded proto files
    /// - Returns: Array of loaded ProtoFile entities
    func getLoadedProtos() -> [ProtoFile]
    
    /// Gets the message descriptor for a specific message type from loaded protos
    /// - Parameter typeName: Fully qualified message type name (e.g., ".package.MessageName" or "MessageName")
    /// - Returns: MessageDescriptor for dynamic message creation
    /// - Throws: ProtoRepositoryError if type not found in loaded protos
    func getMessageDescriptor(forType typeName: String) throws -> MessageDescriptor
}
