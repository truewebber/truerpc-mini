import XCTest
import SwiftProtoReflect
import GRPCCore
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
    
    // MARK: - Server Address Parsing
    
    func test_parseServerAddress_withHostAndPort_returnsCorrectValues() throws {
        // Given
        let address = "localhost:50051"
        
        // When
        let (host, port) = try sut.parseServerAddress(address)
        
        // Then
        XCTAssertEqual(host, "localhost")
        XCTAssertEqual(port, 50051)
    }
    
    func test_parseServerAddress_withOnlyHost_usesDefaultPort() throws {
        // Given
        let address = "api.example.com"
        
        // When
        let (host, port) = try sut.parseServerAddress(address)
        
        // Then
        XCTAssertEqual(host, "api.example.com")
        XCTAssertEqual(port, 50051)
    }
    
    func test_parseServerAddress_withHttpProtocol_stripsProtocol() throws {
        // Given
        let address = "http://localhost:8080"
        
        // When
        let (host, port) = try sut.parseServerAddress(address)
        
        // Then
        XCTAssertEqual(host, "localhost")
        XCTAssertEqual(port, 8080)
    }
    
    func test_parseServerAddress_withHttpsProtocol_stripsProtocol() throws {
        // Given
        let address = "https://api.example.com:443"
        
        // When
        let (host, port) = try sut.parseServerAddress(address)
        
        // Then
        XCTAssertEqual(host, "api.example.com")
        XCTAssertEqual(port, 443)
    }
    
    // MARK: - TLS Detection Tests
    
    func test_shouldUseTLS_withPort443_returnsTrue() {
        // Given
        let port = 443
        let url = "example.com:443"
        
        // When
        let result = sut.shouldUseTLS(port: port, url: url)
        
        // Then
        XCTAssertTrue(result, "Port 443 should use TLS")
    }
    
    func test_shouldUseTLS_withPort50051_returnsFalse() {
        // Given
        let port = 50051
        let url = "localhost:50051"
        
        // When
        let result = sut.shouldUseTLS(port: port, url: url)
        
        // Then
        XCTAssertFalse(result, "Port 50051 should use plaintext")
    }
    
    func test_shouldUseTLS_withPort80_returnsFalse() {
        // Given
        let port = 80
        let url = "example.com:80"
        
        // When
        let result = sut.shouldUseTLS(port: port, url: url)
        
        // Then
        XCTAssertFalse(result, "Port 80 should use plaintext")
    }
    
    func test_shouldUseTLS_withPort8080_returnsFalse() {
        // Given
        let port = 8080
        let url = "example.com:8080"
        
        // When
        let result = sut.shouldUseTLS(port: port, url: url)
        
        // Then
        XCTAssertFalse(result, "Custom port should use plaintext unless it's 443")
    }
    
    func test_parseServerAddress_withEmptyString_throwsError() {
        // Given
        let address = ""
        
        // When/Then
        XCTAssertThrowsError(try sut.parseServerAddress(address)) { error in
            guard case GrpcClientError.networkError = error else {
                XCTFail("Expected networkError")
                return
            }
        }
    }
    
    func test_parseServerAddress_withInvalidPort_usesDefaultPort() throws {
        // Given
        let address = "localhost:invalid"
        
        // When
        let (host, port) = try sut.parseServerAddress(address)
        
        // Then
        XCTAssertEqual(host, "localhost")
        XCTAssertEqual(port, 50051) // Falls back to default
    }
    
    // MARK: - Error Mapping
    
    func test_mapGrpcError_withUnavailable_returnsUnavailable() {
        // Given
        let rpcError = RPCError(code: .unavailable, message: "Service unavailable")
        
        // When
        let result = sut.mapGrpcError(rpcError)
        
        // Then
        XCTAssertEqual(result, .unavailable)
    }
    
    func test_mapGrpcError_withDeadlineExceeded_returnsTimeout() {
        // Given
        let rpcError = RPCError(code: .deadlineExceeded, message: "Deadline exceeded")
        
        // When
        let result = sut.mapGrpcError(rpcError)
        
        // Then
        XCTAssertEqual(result, .timeout)
    }
    
    func test_mapGrpcError_withOtherCode_returnsNetworkError() {
        // Given
        let rpcError = RPCError(code: .unknown, message: "Unknown error")
        
        // When
        let result = sut.mapGrpcError(rpcError)
        
        // Then
        if case .networkError(let message) = result {
            XCTAssertTrue(message.contains("Unknown"))
        } else {
            XCTFail("Expected networkError")
        }
    }
    
    // MARK: - Execute Unary (Integration-style tests)
    
    func test_executeUnary_getsMessageDescriptorsFromRepository() async throws {
        // Given
        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.Request",
            outputType: ".test.Response"
        )
        let request = RequestDraft(
            jsonBody: #"{"name": "test"}"#,
            url: "localhost:50051",
            method: method
        )
        
        // Create descriptors for input and output
        var inputDescriptor = MessageDescriptor(name: "Request", parent: fileDescriptor)
        inputDescriptor.addField(FieldDescriptor(name: "name", number: 1, type: .string))
        
        var outputDescriptor = MessageDescriptor(name: "Response", parent: fileDescriptor)
        outputDescriptor.addField(FieldDescriptor(name: "result", number: 1, type: .string))
        
        // Setup mock to return different descriptors based on type
        mockRepository.inputDescriptor = inputDescriptor
        mockRepository.outputDescriptor = outputDescriptor
        
        // When - This will fail trying to connect to localhost:50051, but that's ok
        // We're testing that it calls the repository correctly
        do {
            _ = try await sut.executeUnary(request: request, method: method)
            XCTFail("Should throw network error")
        } catch {
            // Expected to fail at network level
            // But we can verify repository was called
            XCTAssertTrue(mockRepository.getMessageDescriptorCalled)
            XCTAssertTrue(mockRepository.capturedTypeNames.contains(".test.Request"))
            XCTAssertTrue(mockRepository.capturedTypeNames.contains(".test.Response"))
        }
    }
    
    func test_executeUnary_whenRepositoryThrows_propagatesError() async {
        // Given
        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.NonExistent",
            outputType: ".test.Response"
        )
        let request = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: method
        )
        
        mockRepository.shouldThrow = true
        
        // When/Then
        do {
            _ = try await sut.executeUnary(request: request, method: method)
            XCTFail("Should throw error")
        } catch {
            // Should get repository error (messageTypeNotFound)
            XCTAssertTrue(error is ProtoRepositoryError)
        }
    }
    
    func test_executeUnary_withInvalidJSON_throwsError() async {
        // Given
        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.Request",
            outputType: ".test.Response"
        )
        let request = RequestDraft(
            jsonBody: "{invalid json",
            url: "localhost:50051",
            method: method
        )
        
        mockRepository.stubbedMessageDescriptor = messageDescriptor
        
        // When/Then
        do {
            _ = try await sut.executeUnary(request: request, method: method)
            XCTFail("Should throw error")
        } catch {
            // Should get JSON parsing error
            XCTAssertNotNil(error)
        }
    }
    
    func test_executeUnary_withInvalidServerAddress_throwsError() async {
        // Given
        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.Request",
            outputType: ".test.Response"
        )
        let request = RequestDraft(
            jsonBody: "{}",
            url: "", // Invalid empty address
            method: method
        )
        
        mockRepository.stubbedMessageDescriptor = messageDescriptor
        
        // When/Then
        do {
            _ = try await sut.executeUnary(request: request, method: method)
            XCTFail("Should throw error")
        } catch let error as GrpcClientError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Expected GrpcClientError, got \(error)")
        }
    }
}

// MARK: - Mock Repository

fileprivate class MockProtoRepository: ProtoRepositoryProtocol {
    var stubbedMessageDescriptor: MessageDescriptor?
    var inputDescriptor: MessageDescriptor?
    var outputDescriptor: MessageDescriptor?
    var getMessageDescriptorCalled = false
    var capturedTypeName: String?
    var capturedTypeNames: [String] = []
    var shouldThrow = false
    
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
        capturedTypeNames.append(typeName)
        
        if shouldThrow {
            throw ProtoRepositoryError.messageTypeNotFound(typeName)
        }
        
        // Return specific descriptor based on type name
        if typeName.contains("Request"), let descriptor = inputDescriptor {
            return descriptor
        }
        if typeName.contains("Response"), let descriptor = outputDescriptor {
            return descriptor
        }
        
        guard let descriptor = stubbedMessageDescriptor else {
            throw ProtoRepositoryError.messageTypeNotFound(typeName)
        }
        
        return descriptor
    }
}
