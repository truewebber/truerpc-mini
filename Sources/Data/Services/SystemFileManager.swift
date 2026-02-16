import Foundation

/// System implementation of FileManagerProtocol
/// Wraps Foundation FileManager for file operations
public final class SystemFileManager: FileManagerProtocol {
    
    private let fileManager = FileManager.default
    
    public init() {}
    
    /// Write data to file at given URL
    /// Creates intermediate directories if needed
    /// - Parameters:
    ///   - data: Data to write
    ///   - url: Destination file URL
    /// - Throws: Error if write fails
    public func write(_ data: Data, to url: URL) throws {
        // Create intermediate directories if needed
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        
        // Write data to file
        try data.write(to: url, options: [.atomic])
    }
}
