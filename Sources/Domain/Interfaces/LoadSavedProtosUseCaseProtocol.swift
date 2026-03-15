import Foundation

/// Protocol for loading saved proto files from URLs
public protocol LoadSavedProtosUseCaseProtocol: Sendable {
    /// Executes loading of proto files from saved URLs
    /// - Parameters:
    ///   - urls: Array of file URLs to load
    ///   - importPaths: Array of directory paths for resolving proto dependencies
    /// - Returns: Array of successfully loaded ProtoFile entities (failures are silently skipped)
    func execute(urls: [URL], importPaths: [String]) async -> [ProtoFile]
}
