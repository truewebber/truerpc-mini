import Foundation

/// System implementation of FileManagerProtocol
/// Wraps Foundation FileManager for file operations
public final class SystemFileManager: FileManagerProtocol {
    public init() {}

    /// Write data to file at given URL
    /// Creates intermediate directories if needed
    /// - Parameters:
    ///   - data: Data to write
    ///   - url: Destination file URL
    /// - Throws: Error if write fails
    public func write(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil)
        }

        try data.write(to: url, options: [.atomic])
    }
}
