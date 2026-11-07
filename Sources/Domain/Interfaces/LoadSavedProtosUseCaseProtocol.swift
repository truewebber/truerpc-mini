import Foundation

/// Protocol for loading saved proto files from URLs
public protocol LoadSavedProtosUseCaseProtocol: Sendable {
    /// Executes loading of proto files from saved URLs
    /// - Parameters:
    ///   - urls: Array of file URLs to load
    ///   - importPaths: Array of directory paths for resolving proto dependencies
    /// - Returns: The files that parsed, plus a failure for every path that did not. A failure does not
    ///   stop the remaining paths from loading.
    func execute(urls: [URL], importPaths: [String]) async -> SavedProtosLoadResult
}
