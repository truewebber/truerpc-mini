import Foundation

/// Protocol for generating mock data for gRPC messages
public protocol MockDataGeneratorProtocol {
    /// Generates mock JSON data for a given message type
    /// - Parameter messageType: The fully qualified message type name (e.g., "GetUserRequest")
    /// - Returns: JSON string with mock data
    /// - Throws: Error if message type not found or generation fails
    func generate(for messageType: String) async throws -> String
}
