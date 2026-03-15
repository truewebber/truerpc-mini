import Foundation

/// Use Case for refreshing (re-parsing) an already-loaded proto file
/// Re-reads the source file from disk and returns an updated ProtoFile entity
public final class RefreshProtoFileUseCase: RefreshProtoFileUseCaseProtocol, Sendable {
    private let repository: ProtoRepositoryProtocol

    public init(repository: ProtoRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(protoFile: ProtoFile, importPaths: [String]) async throws -> ProtoFile {
        try await repository.loadProto(url: protoFile.path, importPaths: importPaths)
    }
}
