import Foundation

/// Protocol defining the contract for importing proto files
/// This abstraction allows the Presentation layer to depend on an interface rather than concrete implementation
public protocol ImportProtoFileUseCaseProtocol {
    /// Executes the proto file import operation without import path resolution
    /// - Parameter url: URL of the proto file to import
    /// - Returns: Parsed ProtoFile entity
    /// - Throws: Error if file cannot be loaded or parsed
    func execute(url: URL) async throws -> ProtoFile
    
    /// Executes the proto file import operation with import path resolution
    /// - Parameters:
    ///   - url: URL of the proto file to import
    ///   - importPaths: Array of directory paths for resolving proto dependencies
    /// - Returns: Parsed ProtoFile entity with resolved dependencies
    /// - Throws: Error if file cannot be loaded, parsed, or dependencies cannot be resolved
    func execute(url: URL, importPaths: [String]) async throws -> ProtoFile
}
