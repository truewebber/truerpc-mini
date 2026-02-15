import XCTest
@testable import TrueRPCMini

/// Tests for GenerateMockDataUseCase - generating mock JSON for gRPC requests
final class GenerateMockDataUseCaseTests: XCTestCase {
    var sut: GenerateMockDataUseCase!
    var mockGenerator: MockDataGenerator!
    
    override func setUp() {
        super.setUp()
        mockGenerator = MockDataGenerator()
        sut = GenerateMockDataUseCase(mockDataGenerator: mockGenerator)
    }
    
    override func tearDown() {
        sut = nil
        mockGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Happy Path
    
    func test_execute_generatesMockJSON() async throws {
        // Given
        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false
        )
        
        // When
        let mockJSON = try await sut.execute(method: method)
        
        // Then
        XCTAssertFalse(mockJSON.isEmpty)
        // Verify it's valid JSON
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: mockJSON.data(using: .utf8)!))
    }
    
    func test_execute_generatesNonEmptyJSON() async throws {
        // Given
        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false
        )
        
        // When
        let mockJSON = try await sut.execute(method: method)
        
        // Then
        XCTAssertTrue(mockJSON.contains("{"))
        XCTAssertTrue(mockJSON.contains("}"))
    }
}
