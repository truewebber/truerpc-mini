import XCTest
@testable import TrueRPCMini
import struct TrueRPCMini.Method

final class ExecuteUnaryRequestUseCaseTests: XCTestCase {
    
    var mockGrpcClient: MockGrpcClient!
    var sut: ExecuteUnaryRequestUseCase!
    
    override func setUp() {
        super.setUp()
        mockGrpcClient = MockGrpcClient()
        sut = ExecuteUnaryRequestUseCase(grpcClient: mockGrpcClient)
    }
    
    override func tearDown() {
        mockGrpcClient = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Success Cases
    
    func test_execute_withValidRequest_callsGrpcClient() async throws {
        // Given
        let method = Method(
            name: "SayHello",
            inputType: "HelloRequest",
            outputType: "HelloResponse"
        )
        let request = RequestDraft(
            jsonBody: #"{"name": "World"}"#,
            url: "localhost:50051",
            method: method
        )
        
        mockGrpcClient.stubbedResponse = GrpcResponse(
            jsonBody: #"{"message": "Hello, World!"}"#,
            responseTime: 0.123,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        // When
        let response = try await sut.execute(request: request, method: method)
        
        // Then
        XCTAssertTrue(mockGrpcClient.executeUnaryCalled)
        XCTAssertEqual(mockGrpcClient.capturedRequest?.jsonBody, request.jsonBody)
        XCTAssertEqual(mockGrpcClient.capturedRequest?.url, request.url)
        XCTAssertEqual(mockGrpcClient.capturedMethod?.name, method.name)
        XCTAssertEqual(response.jsonBody, #"{"message": "Hello, World!"}"#)
        XCTAssertEqual(response.statusCode, 0)
    }
    
    func test_execute_withValidRequest_returnsResponseWithTiming() async throws {
        // Given
        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "User"
        )
        let request = RequestDraft(
            jsonBody: #"{"id": 123}"#,
            url: "api.example.com:443",
            method: method
        )
        
        mockGrpcClient.stubbedResponse = GrpcResponse(
            jsonBody: #"{"id": 123, "name": "Alice"}"#,
            responseTime: 0.456,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        // When
        let response = try await sut.execute(request: request, method: method)
        
        // Then
        XCTAssertEqual(response.responseTime, 0.456, accuracy: 0.001)
        XCTAssertGreaterThan(response.responseTime, 0)
    }
    
    // MARK: - Error Cases
    
    func test_execute_withInvalidJSON_throwsValidationError() async {
        // Given
        let method = Method(
            name: "Test",
            inputType: "Request",
            outputType: "Response"
        )
        let request = RequestDraft(
            jsonBody: "{invalid json",
            url: "localhost:50051",
            method: method
        )
        
        // When/Then
        do {
            _ = try await sut.execute(request: request, method: method)
            XCTFail("Expected error to be thrown")
        } catch let error as GrpcClientError {
            if case .invalidJSON = error {
                // Success - correct error type
            } else {
                XCTFail("Expected invalidJSON error, got \(error)")
            }
        } catch {
            XCTFail("Expected GrpcClientError, got \(error)")
        }
    }
    
    func test_execute_whenClientThrowsNetworkError_propagatesError() async {
        // Given
        let method = Method(
            name: "Test",
            inputType: "Request",
            outputType: "Response"
        )
        let request = RequestDraft(
            jsonBody: #"{"test": "data"}"#,
            url: "invalid.host:9999",
            method: method
        )
        
        mockGrpcClient.shouldThrowError = .networkError("Connection refused")
        
        // When/Then
        do {
            _ = try await sut.execute(request: request, method: method)
            XCTFail("Expected error to be thrown")
        } catch let error as GrpcClientError {
            if case .networkError(let message) = error {
                XCTAssertEqual(message, "Connection refused")
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Expected GrpcClientError, got \(error)")
        }
    }
    
    func test_execute_whenClientThrowsTimeout_propagatesError() async {
        // Given
        let method = Method(
            name: "SlowMethod",
            inputType: "Request",
            outputType: "Response"
        )
        let request = RequestDraft(
            jsonBody: #"{"test": "data"}"#,
            url: "slow.server:50051",
            method: method
        )
        
        mockGrpcClient.shouldThrowError = .timeout
        
        // When/Then
        do {
            _ = try await sut.execute(request: request, method: method)
            XCTFail("Expected error to be thrown")
        } catch let error as GrpcClientError {
            XCTAssertEqual(error, .timeout)
        } catch {
            XCTFail("Expected GrpcClientError.timeout, got \(error)")
        }
    }
    
    func test_execute_withEmptyJSON_callsGrpcClientWithEmptyBody() async throws {
        // Given
        let method = Method(
            name: "EmptyRequest",
            inputType: "google.protobuf.Empty",
            outputType: "Response"
        )
        let request = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: method
        )
        
        mockGrpcClient.stubbedResponse = GrpcResponse(
            jsonBody: #"{"success": true}"#,
            responseTime: 0.05,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        // When
        let response = try await sut.execute(request: request, method: method)
        
        // Then
        XCTAssertTrue(mockGrpcClient.executeUnaryCalled)
        XCTAssertEqual(mockGrpcClient.capturedRequest?.jsonBody, "{}")
        XCTAssertEqual(response.jsonBody, #"{"success": true}"#)
    }
}

// MARK: - Mock

class MockGrpcClient: GrpcClientProtocol {
    var executeUnaryCalled = false
    var capturedRequest: RequestDraft?
    var capturedMethod: TrueRPCMini.Method?
    var stubbedResponse: GrpcResponse?
    var shouldThrowError: GrpcClientError?
    
    func executeUnary(request: RequestDraft, method: TrueRPCMini.Method) async throws -> GrpcResponse {
        executeUnaryCalled = true
        capturedRequest = request
        capturedMethod = method
        
        if let error = shouldThrowError {
            throw error
        }
        
        guard let response = stubbedResponse else {
            throw GrpcClientError.unknown("No stubbed response")
        }
        
        return response
    }
}
