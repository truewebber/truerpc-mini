import Foundation

/// Protocol defining the contract for refreshing (re-parsing) an already-loaded proto file
public protocol RefreshProtoFileUseCaseProtocol: Sendable {
    /// Re-parses the proto file at the given ProtoFile's path and returns an updated entity
    /// - Parameters:
    ///   - protoFile: The existing ProtoFile whose source file should be re-parsed
    ///   - importPaths: Directory paths for resolving proto import dependencies
    /// - Returns: Updated ProtoFile entity reflecting the current file contents
    /// - Throws: Error if the file cannot be read, has been deleted, or fails to parse
    func execute(protoFile: ProtoFile, importPaths: [String]) async throws -> ProtoFile
}
