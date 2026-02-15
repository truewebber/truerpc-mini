import XCTest
import SwiftProtoReflect
@testable import TrueRPCMini

final class GrpcSwiftDynamicClientTests: XCTestCase {
    
    var sut: GrpcSwiftDynamicClient!
    fileprivate var mockRepository: MockProtoRepository!
    var fileDescriptor: FileDescriptor!
    var messageDescriptor: MessageDescriptor!
    
    override func setUp() {
        super.setUp()
        
        // Create file descriptor
        fileDescriptor = FileDescriptor(name: "test.proto", package: "test")
        
        // Create message descriptor for Person
        var tempDescriptor = MessageDescriptor(name: "Person", parent: fileDescriptor)
        let nameField = FieldDescriptor(name: "name", number: 1, type: .string)
        let ageField = FieldDescriptor(name: "age", number: 2, type: .int32)
        tempDescriptor.addField(nameField)
        tempDescriptor.addField(ageField)
        messageDescriptor = tempDescriptor
        
        // Create mock repository
        mockRepository = MockProtoRepository()
        mockRepository.stubbedMessageDescriptor = messageDescriptor
        
        sut = GrpcSwiftDynamicClient(protoRepository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        messageDescriptor = nil
        fileDescriptor = nil
        super.tearDown()
    }
    
    // MARK: - JSON Parsing
    
    func test_parseJSON_withValidJSON_createsDynamicMessage() throws {
        // Given
        let jsonString = #"{"name": "Alice", "age": 30}"#
        
        // When
        let result = try sut.parseJSON(jsonString, using: messageDescriptor)
        
        // Then
        XCTAssertEqual(try result.get(forField: "name") as? String, "Alice")
        XCTAssertEqual(try result.get(forField: "age") as? Int32, 30)
    }
    
    func test_parseJSON_withInvalidJSON_throwsError() throws {
        // Given
        let jsonString = "{invalid json"
        
        // When/Then
        XCTAssertThrowsError(try sut.parseJSON(jsonString, using: messageDescriptor))
    }
    
    func test_parseJSON_withEmptyJSON_createsEmptyMessage() throws {
        // Given
        let jsonString = "{}"
        let emptyDescriptor = MessageDescriptor(name: "Empty", parent: fileDescriptor)
        
        // When
        let result = try sut.parseJSON(jsonString, using: emptyDescriptor)
        
        // Then
        XCTAssertNotNil(result)
    }
    
    // MARK: - Message to JSON
    
    func test_messageToJSON_withValidMessage_returnsJSONString() throws {
        // Given
        var message = try MessageFactory().createMessage(from: messageDescriptor)
        try message.set("Bob", forField: "name")
        try message.set(Int32(25), forField: "age")
        
        // When
        let jsonString = try sut.messageToJSON(message)
        
        // Then
        XCTAssertTrue(jsonString.contains("Bob"))
        XCTAssertTrue(jsonString.contains("25"))
        
        // Verify it's valid JSON
        let jsonData = jsonString.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(parsed)
    }
    
    func test_messageToJSON_withEmptyMessage_returnsEmptyObject() throws {
        // Given
        let emptyDescriptor = MessageDescriptor(name: "Empty", parent: fileDescriptor)
        let message = try MessageFactory().createMessage(from: emptyDescriptor)
        
        // When
        let jsonString = try sut.messageToJSON(message)
        
        // Then
        XCTAssertEqual(jsonString, "{}")
    }
}

// MARK: - Mock Repository

fileprivate class MockProtoRepository: ProtoRepositoryProtocol {
    var stubbedMessageDescriptor: MessageDescriptor?
    var getMessageDescriptorCalled = false
    var capturedTypeName: String?
    
    func loadProto(url: URL) async throws -> ProtoFile {
        fatalError("Not implemented in mock")
    }
    
    func loadProto(url: URL, importPaths: [String]) async throws -> ProtoFile {
        fatalError("Not implemented in mock")
    }
    
    func getLoadedProtos() -> [ProtoFile] {
        return []
    }
    
    func getMessageDescriptor(forType typeName: String) throws -> MessageDescriptor {
        getMessageDescriptorCalled = true
        capturedTypeName = typeName
        
        guard let descriptor = stubbedMessageDescriptor else {
            throw ProtoRepositoryError.messageTypeNotFound(typeName)
        }
        
        return descriptor
    }
}
