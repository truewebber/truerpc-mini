import Foundation

/// Generator for mock JSON data from proto message types
/// MVP implementation: Returns empty JSON object
/// Future: Will use SwiftProtoReflect to generate realistic mock data
public final class MockDataGenerator: MockDataGeneratorProtocol {
    public init() {}
    
    /// Generates mock JSON data for a given message type
    /// - Parameter messageType: The fully qualified message type name
    /// - Returns: JSON string with mock data (currently empty object)
    /// - Throws: Error if generation fails
    public func generate(for messageType: String) async throws -> String {
        // MVP: Return empty JSON object
        // TODO: Use SwiftProtoReflect to generate realistic mock data with default values
        return "{}"
    }
}
