import Foundation

/// Protocol defining the contract for proto file repository
/// Follows Dependency Inversion Principle - Domain defines the interface
public protocol ProtoRepositoryProtocol {
    /// Loads and parses a proto file from the given URL
    /// - Parameter url: File URL pointing to a .proto file
    /// - Returns: Parsed ProtoFile entity
    /// - Throws: Error if file cannot be read or parsed
    func loadProto(url: URL) async throws -> ProtoFile
    
    /// Returns all currently loaded proto files
    /// - Returns: Array of loaded ProtoFile entities
    func getLoadedProtos() -> [ProtoFile]
}
