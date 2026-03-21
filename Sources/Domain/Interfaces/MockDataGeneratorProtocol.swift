import Foundation

/// Protocol for generating mock data for gRPC messages
public protocol MockDataGeneratorProtocol: Sendable {
    /// Generates mock JSON data for a given message type within a proto file context.
    /// - Parameters:
    ///   - messageType: The fully qualified message type name (e.g., "GetUserRequest")
    ///   - protoFile: The file that defines the message (for descriptor pool resolution)
    /// - Returns: JSON string with mock data
    /// - Throws: Error if message type not found or generation fails
    func generate(for messageType: String, in protoFile: ProtoFile) async throws -> String
}
