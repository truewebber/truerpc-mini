import Foundation

/// Use case for generating mock JSON data for gRPC method inputs
/// Delegates to MockDataGenerator to create realistic test data
public final class GenerateMockDataUseCase: GenerateMockDataUseCaseProtocol {
    private let mockDataGenerator: MockDataGeneratorProtocol

    public init(mockDataGenerator: MockDataGeneratorProtocol) {
        self.mockDataGenerator = mockDataGenerator
    }

    /// Executes mock data generation for a method's input type
    /// - Parameters:
    ///   - method: The gRPC method to generate data for
    ///   - protoFile: The proto file that contains the method
    /// - Returns: JSON string with mock data for the method's input type
    /// - Throws: Error if generation fails
    public func execute(method: Method, protoFile: ProtoFile) async throws -> String {
        try await mockDataGenerator.generate(for: method.inputType, in: protoFile)
    }
}
