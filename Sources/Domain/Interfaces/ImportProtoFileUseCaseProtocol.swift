import Foundation

/// Protocol defining the contract for importing proto files
/// This abstraction allows the Presentation layer to depend on an interface rather than concrete implementation
public protocol ImportProtoFileUseCaseProtocol {
    /// Executes the proto file import operation
    /// - Parameter url: URL of the proto file to import
    /// - Returns: Parsed ProtoFile entity
    /// - Throws: Error if file cannot be loaded or parsed
    func execute(url: URL) async throws -> ProtoFile
}
