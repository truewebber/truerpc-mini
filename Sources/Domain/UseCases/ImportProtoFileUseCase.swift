import Foundation

/// Use Case for importing proto files
/// Orchestrates the business logic of loading and validating proto files
public final class ImportProtoFileUseCase: ImportProtoFileUseCaseProtocol {
    private let repository: ProtoRepositoryProtocol
    
    public init(repository: ProtoRepositoryProtocol) {
        self.repository = repository
    }
    
    /// Executes the proto file import operation without import path resolution
    /// - Parameter url: URL of the proto file to import
    /// - Returns: Parsed ProtoFile entity
    /// - Throws: Error if file cannot be loaded or parsed
    public func execute(url: URL) async throws -> ProtoFile {
        return try await repository.loadProto(url: url)
    }
    
    /// Executes the proto file import operation with import path resolution
    /// - Parameters:
    ///   - url: URL of the proto file to import
    ///   - importPaths: Array of directory paths for resolving proto dependencies
    /// - Returns: Parsed ProtoFile entity with resolved dependencies
    /// - Throws: Error if file cannot be loaded, parsed, or dependencies cannot be resolved
    public func execute(url: URL, importPaths: [String]) async throws -> ProtoFile {
        return try await repository.loadProto(url: url, importPaths: importPaths)
    }
}
