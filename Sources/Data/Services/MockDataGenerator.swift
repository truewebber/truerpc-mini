import Foundation

/// Generator for mock JSON data from proto message types
/// MVP implementation: Returns empty JSON object
/// Future: Will use SwiftProtoReflect to generate realistic mock data
public final class MockDataGenerator: MockDataGeneratorProtocol, Sendable {
    public init() {}

    /// Generates mock JSON data for a given message type
    /// - Parameters:
    ///   - messageType: The fully qualified message type name (unused in stub)
    ///   - protoFile: The defining proto file (unused in stub)
    /// - Returns: JSON string with mock data (currently empty object)
    /// - Throws: Error if generation fails
    public func generate(for _: String, in _: ProtoFile) throws -> String {
        // MVP: Return empty JSON object
        // TODO: Use SwiftProtoReflect to generate realistic mock data with default values
        "{}"
    }
}
