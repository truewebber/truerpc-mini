import XCTest
@testable import TrueRPCMini

/// Tests for MockDataGenerator - generating mock JSON from proto message types
final class MockDataGeneratorTests: XCTestCase {
    var sut: MockDataGenerator!
    
    override func setUp() {
        super.setUp()
        sut = MockDataGenerator()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Happy Path
    
    func test_generate_returnsValidJSON() async throws {
        // Given
        let messageType = "TestMessage"
        
        // When
        let json = try await sut.generate(for: messageType)
        
        // Then
        XCTAssertFalse(json.isEmpty)
        // Verify it's valid JSON
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: json.data(using: .utf8)!))
    }
    
    func test_generate_returnsJSONObject() async throws {
        // Given
        let messageType = "TestMessage"
        
        // When
        let json = try await sut.generate(for: messageType)
        
        // Then
        XCTAssertTrue(json.contains("{"))
        XCTAssertTrue(json.contains("}"))
    }
    
    func test_generate_multipleCalls_returnsConsistentFormat() async throws {
        // Given
        let messageType = "TestMessage"
        
        // When
        let json1 = try await sut.generate(for: messageType)
        let json2 = try await sut.generate(for: messageType)
        
        // Then
        // Both should be valid JSON
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: json1.data(using: .utf8)!))
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: json2.data(using: .utf8)!))
    }
}
