import XCTest
import SwiftProtoReflect
@testable import TrueRPCMini

final class DynamicMessageDeserializerTests: XCTestCase {
    
    var fileDescriptor: FileDescriptor!
    var messageDescriptor: MessageDescriptor!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create file descriptor
        fileDescriptor = FileDescriptor(name: "test.proto", package: "test")
        
        // Create message descriptor for Person
        var tempDescriptor = MessageDescriptor(name: "Person", parent: fileDescriptor)
        let nameField = FieldDescriptor(name: "name", number: 1, type: .string)
        let ageField = FieldDescriptor(name: "age", number: 2, type: .int32)
        tempDescriptor.addField(nameField)
        tempDescriptor.addField(ageField)
        messageDescriptor = tempDescriptor
    }
    
    override func tearDown() {
        messageDescriptor = nil
        fileDescriptor = nil
        super.tearDown()
    }
    
    func test_deserialize_withValidBinaryData_returnsDynamicMessage() throws {
        // Given
        var originalMessage = try MessageFactory().createMessage(from: messageDescriptor)
        try originalMessage.set("Alice", forField: "name")
        try originalMessage.set(Int32(30), forField: "age")
        
        let binaryData = try BinarySerializer().serialize(originalMessage)
        let bytes = [UInt8](binaryData)
        
        let sut = DynamicMessageDeserializer(messageDescriptor: messageDescriptor)
        
        // When
        let deserializedMessage = try sut.deserialize(bytes)
        
        // Then
        XCTAssertEqual(try deserializedMessage.get(forField: "name") as? String, "Alice")
        XCTAssertEqual(try deserializedMessage.get(forField: "age") as? Int32, 30)
    }
    
    func test_deserialize_withEmptyBytes_returnsEmptyMessage() throws {
        // Given
        let bytes: [UInt8] = []
        let sut = DynamicMessageDeserializer(messageDescriptor: messageDescriptor)
        
        // When
        let message = try sut.deserialize(bytes)
        
        // Then - should have empty/default values
        XCTAssertNotNil(message)
    }
    
    func test_deserialize_withInvalidBytes_throwsError() throws {
        // Given
        let invalidBytes: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
        let sut = DynamicMessageDeserializer(messageDescriptor: messageDescriptor)
        
        // When/Then
        XCTAssertThrowsError(try sut.deserialize(invalidBytes)) { error in
            // Should throw some kind of deserialization error
            XCTAssertNotNil(error)
        }
    }
}
