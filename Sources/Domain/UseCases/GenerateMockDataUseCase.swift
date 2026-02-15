import Foundation

/// Use case for generating mock JSON data for gRPC method inputs
/// Delegates to MockDataGenerator to create realistic test data
public class GenerateMockDataUseCase {
    private let mockDataGenerator: MockDataGeneratorProtocol
    
    public init(mockDataGenerator: MockDataGeneratorProtocol) {
        self.mockDataGenerator = mockDataGenerator
    }
    
    /// Executes mock data generation for a method's input type
    /// - Parameter method: The gRPC method to generate data for
    /// - Returns: JSON string with mock data for the method's input type
    /// - Throws: Error if generation fails
    public func execute(method: Method) async throws -> String {
        return try await mockDataGenerator.generate(for: method.inputType)
    }
}
