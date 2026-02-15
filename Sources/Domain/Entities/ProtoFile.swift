import Foundation

/// Represents a parsed Protocol Buffer file
/// Pure Domain entity - independent of any external library
public struct ProtoFile: Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let path: URL
    public let services: [Service]
    
    public init(id: UUID = UUID(), name: String, path: URL, services: [Service]) {
        self.id = id
        self.name = name
        self.path = path
        self.services = services
    }
}
