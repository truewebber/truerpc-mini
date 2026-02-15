import Foundation

/// Represents a gRPC service definition
public struct Service: Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let methods: [Method]
    
    public init(id: UUID = UUID(), name: String, methods: [Method]) {
        self.id = id
        self.name = name
        self.methods = methods
    }
}
