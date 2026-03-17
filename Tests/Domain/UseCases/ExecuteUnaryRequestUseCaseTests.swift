import struct TrueRPCMini.Method
import XCTest
@testable import TrueRPCMini

@MainActor
final class ExecuteUnaryRequestUseCaseTests: XCTestCase {
    var mockGrpcClient: MockGrpcClient!
    var mockTelemetry: MockTelemetryService!
    var sut: ExecuteUnaryRequestUseCase!

    override func setUp() async throws {
        try await super.setUp()
        mockGrpcClient = MockGrpcClient()
        mockTelemetry = MockTelemetryService()
        sut = ExecuteUnaryRequestUseCase(grpcClient: mockGrpcClient, telemetry: mockTelemetry)
    }

    override func tearDown() async throws {
        mockGrpcClient = nil
        mockTelemetry = nil
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Success Cases

    func test_execute_withValidRequest_callsGrpcClient() async throws {
        // Given
        let method = Method(
            name: "SayHello",
            inputType: "HelloRequest",
            outputType: "HelloResponse")
        let request = RequestDraft(
            jsonBody: #"{"name": "World"}"#,
            url: "localhost:50051",
            method: method)

        mockGrpcClient.stubbedResponse = GrpcResponse(
            jsonBody: #"{"message": "Hello, World!"}"#,
            responseTime: 0.123,
            statusCode: 0,
            statusMessage: "OK")

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
            outputType: "User")
        let request = RequestDraft(
            jsonBody: #"{"id": 123}"#,
            url: "api.example.com:443",
            method: method)

        mockGrpcClient.stubbedResponse = GrpcResponse(
            jsonBody: #"{"id": 123, "name": "Alice"}"#,
            responseTime: 0.456,
            statusCode: 0,
            statusMessage: "OK")

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
            outputType: "Response")
        let request = RequestDraft(
            jsonBody: "{invalid json",
            url: "localhost:50051",
            method: method)

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
            outputType: "Response")
        let request = RequestDraft(
            jsonBody: #"{"test": "data"}"#,
            url: "invalid.host:9999",
            method: method)

        mockGrpcClient.shouldThrowError = .networkError("Connection refused")

        // When/Then
        do {
            _ = try await sut.execute(request: request, method: method)
            XCTFail("Expected error to be thrown")
        } catch let error as GrpcClientError {
            if case let .networkError(message) = error {
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
            outputType: "Response")
        let request = RequestDraft(
            jsonBody: #"{"test": "data"}"#,
            url: "slow.server:50051",
            method: method)

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

    // MARK: - Telemetry Events

    func test_execute_whenRequestSucceeds_tracksRequestSentEvent() async throws {
        // Given
        let method = Method(
            name: "SayHello",
            serviceName: "GreetService",
            inputType: "HelloRequest",
            outputType: "HelloResponse")
        let request = RequestDraft(
            jsonBody: #"{"name": "World"}"#,
            url: "localhost:50051",
            method: method)
        mockGrpcClient.stubbedResponse = GrpcResponse(
            jsonBody: #"{"message": "Hello"}"#,
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK")

        // When
        _ = try await sut.execute(request: request, method: method)

        // Then
        let sentEvent = mockTelemetry.trackedEvents.first { $0.name == "request_sent" }
        XCTAssertNotNil(sentEvent)
        XCTAssertEqual(sentEvent?.properties["service_name"], "GreetService")
        XCTAssertEqual(sentEvent?.properties["method_name"], "SayHello")
    }

    func test_execute_whenRequestSucceeds_tracksRequestSucceededEvent() async throws {
        // Given
        let method = Method(
            name: "SayHello",
            serviceName: "GreetService",
            inputType: "HelloRequest",
            outputType: "HelloResponse")
        let request = RequestDraft(
            jsonBody: #"{"name": "World"}"#,
            url: "localhost:50051",
            method: method)
        mockGrpcClient.stubbedResponse = GrpcResponse(
            jsonBody: #"{"message": "Hello"}"#,
            responseTime: 0.5,
            statusCode: 0,
            statusMessage: "OK")

        // When
        _ = try await sut.execute(request: request, method: method)

        // Then
        let succeededEvent = mockTelemetry.trackedEvents.first { $0.name == "request_succeeded" }
        XCTAssertNotNil(succeededEvent)
        XCTAssertEqual(succeededEvent?.properties["service_name"], "GreetService")
        XCTAssertEqual(succeededEvent?.properties["method_name"], "SayHello")
        XCTAssertEqual(succeededEvent?.properties["duration_ms"], "500")
    }

    func test_execute_tracksEventsInOrder_sentBeforeSucceeded() async throws {
        // Given
        let method = Method(
            name: "SayHello",
            serviceName: "GreetService",
            inputType: "HelloRequest",
            outputType: "HelloResponse")
        let request = RequestDraft(
            jsonBody: #"{"name": "World"}"#,
            url: "localhost:50051",
            method: method)
        mockGrpcClient.stubbedResponse = GrpcResponse(
            jsonBody: #"{"message": "Hello"}"#,
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK")

        // When
        _ = try await sut.execute(request: request, method: method)

        // Then
        XCTAssertEqual(mockTelemetry.trackedEvents.count, 2)
        XCTAssertEqual(mockTelemetry.trackedEvents[0].name, "request_sent")
        XCTAssertEqual(mockTelemetry.trackedEvents[1].name, "request_succeeded")
    }

    func test_execute_whenClientThrowsGrpcError_tracksRequestFailedEvent() async {
        // Given
        let method = Method(
            name: "SayHello",
            serviceName: "GreetService",
            inputType: "HelloRequest",
            outputType: "HelloResponse")
        let request = RequestDraft(
            jsonBody: #"{"name": "World"}"#,
            url: "localhost:50051",
            method: method)
        let errorResponse = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 14,
            statusMessage: "UNAVAILABLE")
        mockGrpcClient.shouldThrowError = .grpcError("UNAVAILABLE", response: errorResponse)

        // When
        do {
            _ = try await sut.execute(request: request, method: method)
            XCTFail("Expected error to be thrown")
        } catch {}

        // Then
        let failedEvent = mockTelemetry.trackedEvents.first { $0.name == "request_failed" }
        XCTAssertNotNil(failedEvent)
        XCTAssertEqual(failedEvent?.properties["service_name"], "GreetService")
        XCTAssertEqual(failedEvent?.properties["method_name"], "SayHello")
        XCTAssertEqual(failedEvent?.properties["error_code"], "UNAVAILABLE")
    }

    func test_execute_whenClientThrowsTimeout_tracksRequestFailedWithDeadlineExceeded() async {
        // Given
        let method = Method(
            name: "SayHello",
            serviceName: "GreetService",
            inputType: "HelloRequest",
            outputType: "HelloResponse")
        let request = RequestDraft(
            jsonBody: #"{"name": "World"}"#,
            url: "localhost:50051",
            method: method)
        mockGrpcClient.shouldThrowError = .timeout

        // When
        do {
            _ = try await sut.execute(request: request, method: method)
            XCTFail("Expected error to be thrown")
        } catch {}

        // Then
        let failedEvent = mockTelemetry.trackedEvents.first { $0.name == "request_failed" }
        XCTAssertNotNil(failedEvent)
        XCTAssertEqual(failedEvent?.properties["error_code"], "DEADLINE_EXCEEDED")
    }

    func test_execute_whenClientThrowsUnavailable_tracksRequestFailedWithUnavailable() async {
        // Given
        let method = Method(
            name: "SayHello",
            serviceName: "GreetService",
            inputType: "HelloRequest",
            outputType: "HelloResponse")
        let request = RequestDraft(
            jsonBody: #"{"name": "World"}"#,
            url: "localhost:50051",
            method: method)
        mockGrpcClient.shouldThrowError = .unavailable

        // When
        do {
            _ = try await sut.execute(request: request, method: method)
            XCTFail("Expected error to be thrown")
        } catch {}

        // Then
        let failedEvent = mockTelemetry.trackedEvents.first { $0.name == "request_failed" }
        XCTAssertNotNil(failedEvent)
        XCTAssertEqual(failedEvent?.properties["error_code"], "UNAVAILABLE")
    }

    func test_execute_whenClientThrowsNetworkError_tracksRequestFailedWithUnavailable() async {
        // Given
        let method = Method(
            name: "SayHello",
            serviceName: "GreetService",
            inputType: "HelloRequest",
            outputType: "HelloResponse")
        let request = RequestDraft(
            jsonBody: #"{"name": "World"}"#,
            url: "localhost:50051",
            method: method)
        mockGrpcClient.shouldThrowError = .networkError("Connection refused")

        // When
        do {
            _ = try await sut.execute(request: request, method: method)
            XCTFail("Expected error to be thrown")
        } catch {}

        // Then
        let failedEvent = mockTelemetry.trackedEvents.first { $0.name == "request_failed" }
        XCTAssertNotNil(failedEvent)
        XCTAssertEqual(failedEvent?.properties["error_code"], "UNAVAILABLE")
    }

    func test_execute_whenClientThrowsUnknownError_tracksRequestFailedWithUnknown() async {
        // Given
        let method = Method(
            name: "SayHello",
            serviceName: "GreetService",
            inputType: "HelloRequest",
            outputType: "HelloResponse")
        let request = RequestDraft(
            jsonBody: #"{"name": "World"}"#,
            url: "localhost:50051",
            method: method)
        mockGrpcClient.shouldThrowError = .unknown("Something went wrong")

        // When
        do {
            _ = try await sut.execute(request: request, method: method)
            XCTFail("Expected error to be thrown")
        } catch {}

        // Then
        let failedEvent = mockTelemetry.trackedEvents.first { $0.name == "request_failed" }
        XCTAssertNotNil(failedEvent)
        XCTAssertEqual(failedEvent?.properties["error_code"], "UNKNOWN")
    }

    func test_execute_withInvalidJSON_doesNotFireAnyTelemetryEvents() async {
        // Given - JSON validation fails before network call
        let method = Method(
            name: "SayHello",
            serviceName: "GreetService",
            inputType: "HelloRequest",
            outputType: "HelloResponse")
        let request = RequestDraft(
            jsonBody: "{invalid json",
            url: "localhost:50051",
            method: method)

        // When
        do {
            _ = try await sut.execute(request: request, method: method)
            XCTFail("Expected error to be thrown")
        } catch {}

        // Then - no telemetry events fired for local validation failures
        XCTAssertTrue(mockTelemetry.trackedEvents.isEmpty)
    }

    // MARK: - Other Tests

    func test_execute_withEmptyJSON_callsGrpcClientWithEmptyBody() async throws {
        // Given
        let method = Method(
            name: "EmptyRequest",
            inputType: "google.protobuf.Empty",
            outputType: "Response")
        let request = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: method)

        mockGrpcClient.stubbedResponse = GrpcResponse(
            jsonBody: #"{"success": true}"#,
            responseTime: 0.05,
            statusCode: 0,
            statusMessage: "OK")

        // When
        let response = try await sut.execute(request: request, method: method)

        // Then
        XCTAssertTrue(mockGrpcClient.executeUnaryCalled)
        XCTAssertEqual(mockGrpcClient.capturedRequest?.jsonBody, "{}")
        XCTAssertEqual(response.jsonBody, #"{"success": true}"#)
    }
}

// MARK: - Mock

@MainActor
final class MockGrpcClient: GrpcClientProtocol {
    var executeUnaryCalled = false
    var capturedRequest: RequestDraft?
    var capturedMethod: TrueRPCMini.Method?
    var stubbedResponse: GrpcResponse?
    var shouldThrowError: GrpcClientError?

    func executeUnary(request: RequestDraft, method: TrueRPCMini.Method) throws -> GrpcResponse {
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
