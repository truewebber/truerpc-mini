import Foundation

/// Protocol for watching proto files and their transitive dependencies for on-disk changes.
/// Domain-layer contract — implemented in the Data layer.
public protocol ProtoFileWatcherProtocol {
    /// Start watching all files associated with `protoFile` (root + dependency paths).
    /// Replaces any existing watch for the same `protoFile.path`.
    func startWatching(_ protoFile: ProtoFile)

    /// Stop watching all files associated with `protoFile`.
    func stopWatching(_ protoFile: ProtoFile)

    /// Stream of root `ProtoFile` values whose on-disk content has changed.
    var changes: AsyncStream<ProtoFile> { get }
}
