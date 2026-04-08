import SwiftProtoReflect
import XCTest
@testable import TrueRPCMini

final class DynamicMessageSerializerTests: XCTestCase {
    var sut: DynamicMessageSerializer!
    var fileDescriptor: FileDescriptor!
    var messageDescriptor: MessageDescriptor!

    override func setUp() async throws {
        try await super.setUp()
        sut = DynamicMessageSerializer()

        fileDescriptor = FileDescriptor(name: "test.proto", package: "test")

        var tempDescriptor = MessageDescriptor(name: "Person", parent: fileDescriptor)
        let nameField = FieldDescriptor(name: "name", number: 1, type: .string)
        let ageField = FieldDescriptor(name: "age", number: 2, type: .int32)
        tempDescriptor.addField(nameField)
        tempDescriptor.addField(ageField)
        messageDescriptor = tempDescriptor
    }

    override func tearDown() {
        sut = nil
        messageDescriptor = nil
        fileDescriptor = nil
        super.tearDown()
    }

    func test_serialize_withSimpleMessage_returnsValidBinaryData() async throws {
        // Given
        var message = MessageFactory().createMessage(from: messageDescriptor)
        try message.set("Alice", forField: "name")
        try message.set(Int32(30), forField: "age")

        // When
        let bytes: [UInt8] = try sut.serialize(message)

        // Then
        XCTAssertFalse(bytes.isEmpty)
        XCTAssertGreaterThan(bytes.count, 0)

        // Verify it's valid protobuf by deserializing asynchronously
        let data = Data(bytes)
        let registry = TypeRegistry()
        let deserializer = BinaryDeserializer(options: DeserializationOptions(typeRegistry: registry))
        let decoded = try await deserializer.deserialize(data, using: messageDescriptor)

        XCTAssertEqual(try decoded.get(forField: "name") as? String, "Alice")
        XCTAssertEqual(try decoded.get(forField: "age") as? Int32, 30)
    }

    func test_serialize_withEmptyMessage_returnsMinimalBytes() throws {
        // Given
        let message = MessageFactory().createMessage(from: messageDescriptor)

        // When
        let bytes: [UInt8] = try sut.serialize(message)

        // Then - empty message should serialize to very small or empty byte array
        XCTAssertTrue(bytes.count < 10)
    }

    func test_serialize_withRepeatedFields_handlesArrays() async throws {
        // Given
        var listDescriptor = MessageDescriptor(name: "EmailList", parent: fileDescriptor)
        let emailsField = FieldDescriptor(name: "emails", number: 1, type: .string, isRepeated: true)
        listDescriptor.addField(emailsField)

        var message = MessageFactory().createMessage(from: listDescriptor)
        try message.set(["alice@example.com", "bob@example.com"], forField: "emails")

        // When
        let bytes: [UInt8] = try sut.serialize(message)

        // Then
        XCTAssertFalse(bytes.isEmpty)

        // Verify by deserializing asynchronously
        let data = Data(bytes)
        let registry = TypeRegistry()
        let decoded = try await BinaryDeserializer(
            options: DeserializationOptions(typeRegistry: registry))
            .deserialize(data, using: listDescriptor)
        let emails = try decoded.get(forField: "emails") as? [String]
        XCTAssertEqual(emails?.count, 2)
    }
}
