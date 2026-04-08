import GRPCCore
import SwiftProtoReflect
import XCTest
@testable import TrueRPCMini

final class DynamicMessageDeserializerTests: XCTestCase {
    var fileDescriptor: FileDescriptor!
    var messageDescriptor: MessageDescriptor!

    override func setUp() async throws {
        try await super.setUp()

        fileDescriptor = FileDescriptor(name: "test.proto", package: "test")

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

    func test_deserialize_withValidBinaryData_returnsRawData() throws {
        // Given: a serialized protobuf message
        var originalMessage = MessageFactory().createMessage(from: messageDescriptor)
        try originalMessage.set("Alice", forField: "name")
        try originalMessage.set(Int32(30), forField: "age")

        let binaryData = try BinarySerializer().serialize(originalMessage)
        let bytes = [UInt8](binaryData)

        let sut = DynamicMessageDeserializer()

        // When
        let result = try sut.deserialize(bytes)

        // Then: DynamicMessageDeserializer is a pass-through — it returns the raw bytes as Data
        XCTAssertEqual(result, binaryData)
    }

    func test_deserialize_withEmptyBytes_returnsEmptyData() throws {
        // Given
        let bytes: [UInt8] = []
        let sut = DynamicMessageDeserializer()

        // When
        let result = try sut.deserialize(bytes)

        // Then
        XCTAssertTrue(result.isEmpty)
    }

    func test_deserialize_withArbitraryBytes_returnsTheSameBytes() throws {
        // Given
        let bytes: [UInt8] = [0x01, 0x02, 0x03, 0xFF]
        let sut = DynamicMessageDeserializer()

        // When
        let result = try sut.deserialize(bytes)

        // Then
        XCTAssertEqual(result, Data(bytes))
    }

    func test_deserialize_preservesBinaryContent_roundTrip() async throws {
        // Given: a serialized protobuf message
        var originalMessage = MessageFactory().createMessage(from: messageDescriptor)
        try originalMessage.set("Bob", forField: "name")
        try originalMessage.set(Int32(25), forField: "age")

        let binaryData = try BinarySerializer().serialize(originalMessage)

        // When: pass through DynamicMessageDeserializer then async-deserialize via BinaryDeserializer
        let passThrough = DynamicMessageDeserializer()
        let rawData = try passThrough.deserialize([UInt8](binaryData))

        let registry = TypeRegistry()
        let binaryDeserializer = BinaryDeserializer(options: DeserializationOptions(typeRegistry: registry))
        let decoded = try await binaryDeserializer.deserialize(rawData, using: messageDescriptor)

        // Then
        XCTAssertEqual(try decoded.get(forField: "name") as? String, "Bob")
        XCTAssertEqual(try decoded.get(forField: "age") as? Int32, 25)
    }
}
