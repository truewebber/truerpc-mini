import Foundation

/// Protocol defining the contract for generating mock JSON data for gRPC method inputs
public protocol GenerateMockDataUseCaseProtocol: Sendable {
    /// Generates mock JSON data for a method's input type
    /// - Parameter method: The gRPC method to generate data for
    /// - Returns: JSON string with mock data for the method's input type
    /// - Throws: Error if generation fails
    func execute(method: Method) async throws -> String
}
