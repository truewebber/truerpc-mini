import Foundation

/// Use Case for importing proto files
/// Orchestrates the business logic of loading and validating proto files
public final class ImportProtoFileUseCase {
    private let repository: ProtoRepositoryProtocol
    
    public init(repository: ProtoRepositoryProtocol) {
        self.repository = repository
    }
    
    /// Executes the proto file import operation
    /// - Parameter url: URL of the proto file to import
    /// - Returns: Parsed ProtoFile entity
    /// - Throws: Error if file cannot be loaded or parsed
    public func execute(url: URL) async throws -> ProtoFile {
        return try await repository.loadProto(url: url)
    }
}
