import Foundation

/// Represents a parsed Protocol Buffer file
/// Pure Domain entity - independent of any external library
public struct ProtoFile: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let services: [Service]
    /// Resolved paths of all transitive import dependencies, excluding well-known bundled types.
    public let dependencyPaths: [URL]

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        services: [Service],
        dependencyPaths: [URL] = [])
    {
        self.id = id
        self.name = name
        self.path = path
        self.services = services
        self.dependencyPaths = dependencyPaths
    }
}
