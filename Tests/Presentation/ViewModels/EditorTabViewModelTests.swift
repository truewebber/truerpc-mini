import XCTest
@testable import TrueRPCMini

/// Tests for EditorTabViewModel - managing request editor state
@MainActor
final class EditorTabViewModelTests: XCTestCase {
    var sut: EditorTabViewModel!
    var mockGenerateMockDataUseCase: MockGenerateMockDataUseCase!
    var mockExecuteRequestUseCase: MockExecuteUnaryRequestUseCase!
    var mockExportResponseUseCase: MockExportResponseUseCase!
    var testMethod: TrueRPCMini.Method!
    var testService: Service!
    var testProtoFile: ProtoFile!
    var testEditorTab: EditorTab!
    
    override func setUp() {
        super.setUp()
        mockGenerateMockDataUseCase = MockGenerateMockDataUseCase()
        mockExecuteRequestUseCase = MockExecuteUnaryRequestUseCase()
        mockExportResponseUseCase = MockExportResponseUseCase()
        
        testMethod = TrueRPCMini.Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false
        )
        testService = Service(name: "UserService", methods: [testMethod])
        testProtoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [testService]
        )
        testEditorTab = EditorTab(
            methodName: testMethod.name,
            serviceName: testService.name,
            protoFile: testProtoFile,
            method: testMethod
        )
        
        sut = EditorTabViewModel(
            editorTab: testEditorTab,
            generateMockDataUseCase: mockGenerateMockDataUseCase,
            executeRequestUseCase: mockExecuteRequestUseCase,
            exportResponseUseCase: mockExportResponseUseCase
        )
    }
    
    override func tearDown() {
        sut = nil
        mockGenerateMockDataUseCase = nil
        mockExecuteRequestUseCase = nil
        testMethod = nil
        testService = nil
        testProtoFile = nil
        testEditorTab = nil
        super.tearDown()
    }
    
    // MARK: - Initial State
    
    func test_init_setsInitialState() {
        // Then
        XCTAssertEqual(sut.editorTab.methodName, "GetUser")
        XCTAssertEqual(sut.url, "")
        XCTAssertEqual(sut.requestJson, "")
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.response)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isExecuting)
    }
    
    // MARK: - Load Mock Data
    
    func test_loadMockData_success_updatesRequestJson() async {
        // Given
        mockGenerateMockDataUseCase.mockJSON = "{\"userId\": 1}"
        
        // When
        await sut.loadMockData()
        
        // Then
        XCTAssertEqual(sut.requestJson, "{\"userId\": 1}")
        XCTAssertFalse(sut.isLoading)
    }
    
    func test_loadMockData_setsLoadingState() async {
        // Given
        mockGenerateMockDataUseCase.mockJSON = "{}"
        
        // When
        let loadingStateDuringExecution = Task {
            await sut.loadMockData()
        }
        
        // Small delay to check loading state
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        await loadingStateDuringExecution.value
        
        // Then
        XCTAssertFalse(sut.isLoading) // Should be false after completion
    }
    
    // MARK: - Update JSON
    
    func test_updateJson_updatesRequestJson() {
        // Given
        let newJson = "{\"userId\": 123}"
        
        // When
        sut.updateJson(newJson)
        
        // Then
        XCTAssertEqual(sut.requestJson, newJson)
    }
    
    // MARK: - Update URL
    
    func test_updateUrl_updatesUrl() {
        // Given
        let newUrl = "localhost:50051"
        
        // When
        sut.updateUrl(newUrl)
        
        // Then
        XCTAssertEqual(sut.url, newUrl)
    }
    
    // MARK: - Execute Request
    
    func test_executeRequest_success_updatesResponse() async {
        // Given
        sut.updateJson(#"{"userId": 123}"#)
        sut.updateUrl("localhost:50051")
        
        let expectedResponse = GrpcResponse(
            jsonBody: #"{"id": 123, "name": "Alice"}"#,
            responseTime: 0.123,
            statusCode: 0,
            statusMessage: "OK"
        )
        mockExecuteRequestUseCase.stubbedResponse = expectedResponse
        
        // When
        await sut.executeRequest()
        
        // Then
        XCTAssertNotNil(sut.response)
        XCTAssertEqual(sut.response?.jsonBody, #"{"id": 123, "name": "Alice"}"#)
        XCTAssertEqual(sut.response?.statusCode, 0)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isExecuting)
    }
    
    func test_executeRequest_setsExecutingState() async {
        // Given
        sut.updateJson("{}")
        sut.updateUrl("localhost:50051")
        mockExecuteRequestUseCase.stubbedResponse = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        // When
        await sut.executeRequest()
        
        // Then
        XCTAssertFalse(sut.isExecuting) // Should be false after completion
    }
    
    func test_executeRequest_failure_setsError() async {
        // Given
        sut.updateJson("{}")
        sut.updateUrl("invalid-host:9999")
        mockExecuteRequestUseCase.shouldThrowError = .networkError("Connection refused")
        
        // When
        await sut.executeRequest()
        
        // Then
        XCTAssertNil(sut.response)
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.error!.contains("Connection refused"))
        XCTAssertFalse(sut.isExecuting)
    }
    
    func test_executeRequest_clearsPreviousResponseAndError() async {
        // Given
        sut.updateJson("{}")
        sut.updateUrl("localhost:50051")
        
        // Set previous state
        let oldResponse = GrpcResponse(
            jsonBody: "old",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK"
        )
        mockExecuteRequestUseCase.stubbedResponse = oldResponse
        await sut.executeRequest()
        
        XCTAssertNotNil(sut.response)
        
        // Set new state (error)
        mockExecuteRequestUseCase.stubbedResponse = nil
        mockExecuteRequestUseCase.shouldThrowError = .timeout
        
        // When
        await sut.executeRequest()
        
        // Then
        XCTAssertNil(sut.response) // Previous response cleared
        XCTAssertNotNil(sut.error)
    }
    
    func test_executeRequest_callsUseCaseWithCorrectParameters() async {
        // Given
        sut.updateJson(#"{"test": "data"}"#)
        sut.updateUrl("api.example.com:443")
        mockExecuteRequestUseCase.stubbedResponse = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        // When
        await sut.executeRequest()
        
        // Then
        XCTAssertTrue(mockExecuteRequestUseCase.executeCalled)
        XCTAssertEqual(mockExecuteRequestUseCase.capturedRequest?.jsonBody, #"{"test": "data"}"#)
        XCTAssertEqual(mockExecuteRequestUseCase.capturedRequest?.url, "api.example.com:443")
        XCTAssertEqual(mockExecuteRequestUseCase.capturedMethod?.name, "GetUser")
    }
    
    // MARK: - Copy Response Tests
    
    func test_copyResponse_whenResponseExists_copiesJsonToClipboard() {
        // Given
        let testResponse = GrpcResponse(
            jsonBody: #"{"user": "John Doe"}"#,
            responseTime: 0.5,
            statusCode: 0,
            statusMessage: "OK"
        )
        sut.response = testResponse
        
        // When
        sut.copyResponse()
        
        // Then
        let pasteboard = NSPasteboard.general
        let copiedString = pasteboard.string(forType: .string)
        XCTAssertEqual(copiedString, #"{"user": "John Doe"}"#)
    }
    
    func test_copyResponse_whenNoResponse_doesNothing() {
        // Given
        sut.response = nil
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("previous content", forType: .string)
        
        // When
        sut.copyResponse()
        
        // Then
        let pasteboard = NSPasteboard.general
        let content = pasteboard.string(forType: .string)
        XCTAssertEqual(content, "previous content")
    }
    
    // MARK: - Export Response Tests
    
    func test_exportResponse_whenResponseExists_callsExportUseCase() async throws {
        // Given
        let mockExportUseCase = MockExportResponseUseCase()
        let testResponse = GrpcResponse(
            jsonBody: #"{"result": "success"}"#,
            responseTime: 1.2,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        let sutWithExport = EditorTabViewModel(
            editorTab: testEditorTab,
            generateMockDataUseCase: mockGenerateMockDataUseCase,
            executeRequestUseCase: mockExecuteRequestUseCase,
            exportResponseUseCase: mockExportUseCase
        )
        sutWithExport.response = testResponse
        
        let testURL = URL(fileURLWithPath: "/tmp/export.json")
        
        // When
        try await sutWithExport.exportResponse(to: testURL)
        
        // Then
        XCTAssertTrue(mockExportUseCase.executeCalled)
        XCTAssertEqual(mockExportUseCase.capturedResponse?.jsonBody, testResponse.jsonBody)
        XCTAssertEqual(mockExportUseCase.capturedDestination, testURL)
        XCTAssertFalse(mockExportUseCase.capturedIncludeMetadata)
    }
    
    func test_exportResponse_whenNoResponse_doesNothing() async throws {
        // Given
        let mockExportUseCase = MockExportResponseUseCase()
        let sutWithExport = EditorTabViewModel(
            editorTab: testEditorTab,
            generateMockDataUseCase: mockGenerateMockDataUseCase,
            executeRequestUseCase: mockExecuteRequestUseCase,
            exportResponseUseCase: mockExportUseCase
        )
        sutWithExport.response = nil
        
        let testURL = URL(fileURLWithPath: "/tmp/export.json")
        
        // When
        try await sutWithExport.exportResponse(to: testURL)
        
        // Then
        XCTAssertFalse(mockExportUseCase.executeCalled)
    }
}

// MARK: - Mock

class MockGenerateMockDataUseCase: GenerateMockDataUseCase {
    var mockJSON: String = "{}"
    var executeCallCount = 0
    
    init() {
        super.init(mockDataGenerator: MockDataGenerator())
    }
    
    override func execute(method: TrueRPCMini.Method) async throws -> String {
        executeCallCount += 1
        return mockJSON
    }
}

class MockExecuteUnaryRequestUseCase: ExecuteUnaryRequestUseCaseProtocol {
    var executeCalled = false
    var capturedRequest: RequestDraft?
    var capturedMethod: TrueRPCMini.Method?
    var stubbedResponse: GrpcResponse?
    var shouldThrowError: GrpcClientError?
    var shouldThrow: Bool = false
    var errorToThrow: GrpcClientError?
    
    func execute(request: RequestDraft, method: TrueRPCMini.Method) async throws -> GrpcResponse {
        executeCalled = true
        capturedRequest = request
        capturedMethod = method
        
        if shouldThrow, let error = errorToThrow {
            throw error
        }
        
        if let error = shouldThrowError {
            throw error
        }
        
        guard let response = stubbedResponse else {
            throw GrpcClientError.unknown("No stubbed response")
        }
        
        return response
    }
}

class MockExportResponseUseCase: ExportResponseUseCase {
    var executeCalled = false
    var capturedResponse: GrpcResponse?
    var capturedDestination: URL?
    var capturedIncludeMetadata: Bool = false
    
    init() {
        super.init(fileManager: MockFileManager())
    }
    
    override func execute(
        response: GrpcResponse,
        destination: URL,
        includeMetadata: Bool = false
    ) async throws {
        executeCalled = true
        capturedResponse = response
        capturedDestination = destination
        capturedIncludeMetadata = includeMetadata
    }
}

// MARK: - Metadata Tests
extension EditorTabViewModelTests {
    
    func test_init_setsDefaultMetadataState() {
        // Then
        XCTAssertEqual(sut.metadataJson, "{}")
        XCTAssertFalse(sut.isMetadataVisible)
    }
    
    func test_updateMetadata_updatesMetadataJson() {
        // Given
        let newMetadata = #"{"authorization": "Bearer token123"}"#
        
        // When
        sut.updateMetadata(newMetadata)
        
        // Then
        XCTAssertEqual(sut.metadataJson, newMetadata)
    }
    
    func test_toggleMetadataVisibility_togglesState() {
        // Given
        XCTAssertFalse(sut.isMetadataVisible)
        
        // When
        sut.toggleMetadataVisibility()
        
        // Then
        XCTAssertTrue(sut.isMetadataVisible)
        
        // When toggled again
        sut.toggleMetadataVisibility()
        
        // Then
        XCTAssertFalse(sut.isMetadataVisible)
    }
    
    func test_executeRequest_withValidMetadata_sendsMetadata() async {
        // Given
        sut.requestJson = "{}"
        sut.url = "localhost:50051"
        sut.metadataJson = #"{"authorization": "Bearer token"}"#
        
        mockExecuteRequestUseCase.stubbedResponse = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        // When
        await sut.executeRequest()
        
        // Then
        XCTAssertTrue(mockExecuteRequestUseCase.executeCalled)
        XCTAssertNotNil(mockExecuteRequestUseCase.capturedRequest?.metadata)
        XCTAssertEqual(
            mockExecuteRequestUseCase.capturedRequest?.metadata?.headers["authorization"],
            "Bearer token"
        )
    }
    
    func test_executeRequest_withEmptyMetadata_sendsNoMetadata() async {
        // Given
        sut.requestJson = "{}"
        sut.url = "localhost:50051"
        sut.metadataJson = "{}"
        
        mockExecuteRequestUseCase.stubbedResponse = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        // When
        await sut.executeRequest()
        
        // Then
        XCTAssertTrue(mockExecuteRequestUseCase.executeCalled)
        XCTAssertNil(mockExecuteRequestUseCase.capturedRequest?.metadata)
    }
    
    func test_executeRequest_withInvalidMetadataJSON_setsError() async {
        // Given
        sut.requestJson = "{}"
        sut.url = "localhost:50051"
        sut.metadataJson = "{invalid json"
        
        // When
        await sut.executeRequest()
        
        // Then
        XCTAssertNotNil(sut.error, "Error should be set for invalid metadata")
        // Metadata error should prevent request execution
        XCTAssertFalse(mockExecuteRequestUseCase.executeCalled)
    }
    
    func test_executeRequest_withNonObjectMetadata_setsError() async {
        // Given
        sut.requestJson = "{}"
        sut.url = "localhost:50051"
        sut.metadataJson = "[\"array\"]"
        
        // When
        await sut.executeRequest()
        
        // Then
        XCTAssertNotNil(sut.error, "Error should be set for non-object metadata")
        // Metadata error should prevent request execution
        XCTAssertFalse(mockExecuteRequestUseCase.executeCalled)
    }
    
    func test_executeRequest_withGrpcError_setsErrorAndResponse() async {
        // Given
        sut.requestJson = "{}"
        sut.url = "localhost:50051"
        
        let errorResponse = GrpcResponse(
            jsonBody: #"{"error": "not implemented"}"#,
            responseTime: 0.05,
            statusCode: 12, // gRPC UNIMPLEMENTED
            statusMessage: "unimplemented",
            trailers: [
                "grpc-status": "12",
                "grpc-message": "Method not implemented"
            ]
        )
        
        mockExecuteRequestUseCase.shouldThrow = true
        mockExecuteRequestUseCase.errorToThrow = .grpcError("unimplemented", response: errorResponse)
        
        // When
        await sut.executeRequest()
        
        // Then - both error and response should be set
        XCTAssertNotNil(sut.error, "Error message should be set")
        XCTAssertNotNil(sut.response, "Response with metadata should be set for debugging")
        XCTAssertEqual(sut.response?.trailers?["grpc-status"], "12")
        XCTAssertEqual(sut.response?.statusCode, 12)
    }
}

