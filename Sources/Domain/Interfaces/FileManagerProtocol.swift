import Foundation

/// Protocol for file system operations
/// Abstracts file writing for testability
public protocol FileManagerProtocol {
    /// Write data to file at given URL
    /// - Parameters:
    ///   - data: Data to write
    ///   - url: Destination file URL
    /// - Throws: Error if write fails
    func write(_ data: Data, to url: URL) throws
}
