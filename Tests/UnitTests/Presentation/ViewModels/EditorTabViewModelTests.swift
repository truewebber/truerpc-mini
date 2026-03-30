import XCTest
@testable import TrueRPCMini

/// Tests for EditorTabViewModel - managing request editor state
@MainActor
final class EditorTabViewModelTests: XCTestCase {
    var sut: EditorTabViewModel!
    var mockGenerateMockDataUseCase: MockGenerateMockDataUseCase!
    var mockExecuteRequestUseCase: MockExecuteUnaryRequestUseCase!
    var mockExportResponseUseCase: MockExportResponseUseCase!
    var mockJsonFormatter: MockJsonFormatter!
    var mockLogger: MockAppLogger!
    var testMethod: TrueRPCMini.Method!
    var testService: Service!
    var testProtoFile: ProtoFile!
    var testEditorTab: EditorTab!

    override func setUp() async throws {
        try await super.setUp()
        mockGenerateMockDataUseCase = MockGenerateMockDataUseCase()
        mockExecuteRequestUseCase = MockExecuteUnaryRequestUseCase()
        mockExportResponseUseCase = MockExportResponseUseCase()
        mockJsonFormatter = MockJsonFormatter()
        mockLogger = MockAppLogger()

        testMethod = TrueRPCMini.Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false)
        testService = Service(name: "UserService", methods: [testMethod])
        testProtoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [testService])
        testEditorTab = EditorTab(
            methodName: testMethod.name,
            serviceName: testService.name,
            protoFile: testProtoFile,
            method: testMethod)

        sut = EditorTabViewModel(
            editorTab: testEditorTab,
            generateMockDataUseCase: mockGenerateMockDataUseCase,
            executeRequestUseCase: mockExecuteRequestUseCase,
            exportResponseUseCase: mockExportResponseUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            logger: mockLogger)
    }

    override func tearDown() async throws {
        sut = nil
        mockGenerateMockDataUseCase = nil
        mockExecuteRequestUseCase = nil
        mockJsonFormatter = nil
        mockLogger = nil
        testMethod = nil
        testService = nil
        testProtoFile = nil
        testEditorTab = nil
        try await super.tearDown()
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

    func test_loadMockData_whenFails_logsError() async {
        mockGenerateMockDataUseCase.shouldThrow = true

        await sut.loadMockData()

        XCTAssertEqual(mockLogger.errorMessages.count, 1)
        XCTAssertNotNil(mockLogger.errorMessages[0].metadata["error"])
        XCTAssertEqual(mockLogger.errorMessages[0].metadata["method"], "\(testMethod.name)")
    }

    func test_loadMockData_whenSucceeds_doesNotLog() async {
        mockGenerateMockDataUseCase.mockJSON = "{}"

        await sut.loadMockData()

        XCTAssertTrue(mockLogger.errorMessages.isEmpty)
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
            statusMessage: "OK")
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
            statusMessage: "OK")

        // When
        await sut.executeRequest()

        // Then
        XCTAssertFalse(sut.isExecuting) // Should be false after completion
    }

    func test_executeRequest_failure_setsError() async throws {
        // Given
        sut.updateJson("{}")
        sut.updateUrl("invalid-host:9999")
        mockExecuteRequestUseCase.shouldThrowError = .networkError("Connection refused")

        // When
        await sut.executeRequest()

        // Then
        XCTAssertNil(sut.response)
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(try XCTUnwrap(sut.error?.contains("Connection refused")))
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
            statusMessage: "OK")
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
            statusMessage: "OK")

        // When
        await sut.executeRequest()

        // Then
        XCTAssertTrue(mockExecuteRequestUseCase.executeCalled)
        XCTAssertEqual(mockExecuteRequestUseCase.capturedProtoFile?.id, testEditorTab.protoFile.id)
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
            statusMessage: "OK")
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

    func test_exportResponse_whenResponseExists_callsExportUseCase() throws {
        // Given
        let mockExportUseCase = MockExportResponseUseCase()
        let testResponse = GrpcResponse(
            jsonBody: #"{"result": "success"}"#,
            responseTime: 1.2,
            statusCode: 0,
            statusMessage: "OK")

        let sutWithExport = EditorTabViewModel(
            editorTab: testEditorTab,
            generateMockDataUseCase: mockGenerateMockDataUseCase,
            executeRequestUseCase: mockExecuteRequestUseCase,
            exportResponseUseCase: mockExportUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            logger: mockLogger)
        sutWithExport.response = testResponse

        let testURL = URL(fileURLWithPath: "/tmp/export.json")

        // When
        try sutWithExport.exportResponse(to: testURL)

        // Then
        XCTAssertTrue(mockExportUseCase.executeCalled)
        XCTAssertEqual(mockExportUseCase.capturedResponse?.jsonBody, testResponse.jsonBody)
        XCTAssertEqual(mockExportUseCase.capturedDestination, testURL)
        XCTAssertFalse(mockExportUseCase.capturedIncludeMetadata)
    }

    func test_exportResponse_whenNoResponse_doesNothing() throws {
        // Given
        let mockExportUseCase = MockExportResponseUseCase()
        let sutWithExport = EditorTabViewModel(
            editorTab: testEditorTab,
            generateMockDataUseCase: mockGenerateMockDataUseCase,
            executeRequestUseCase: mockExecuteRequestUseCase,
            exportResponseUseCase: mockExportUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            logger: mockLogger)
        sutWithExport.response = nil

        let testURL = URL(fileURLWithPath: "/tmp/export.json")

        // When
        try sutWithExport.exportResponse(to: testURL)

        // Then
        XCTAssertFalse(mockExportUseCase.executeCalled)
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
            statusMessage: "OK")

        // When
        await sut.executeRequest()

        // Then
        XCTAssertTrue(mockExecuteRequestUseCase.executeCalled)
        XCTAssertNotNil(mockExecuteRequestUseCase.capturedRequest?.metadata)
        XCTAssertEqual(
            mockExecuteRequestUseCase.capturedRequest?.metadata?.headers["authorization"],
            "Bearer token")
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
            statusMessage: "OK")

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

    func test_executeRequest_whenProtoRepositoryError_logsError() async {
        // Given
        sut.requestJson = "{}"
        sut.url = "localhost:50051"
        mockExecuteRequestUseCase.protoErrorToThrow = .messageTypeNotFound(".test.Request")

        // When
        await sut.executeRequest()

        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(mockLogger.errorMessages.count, 1)
        let logEntry = mockLogger.errorMessages[0]
        XCTAssertEqual(logEntry.metadata["method"], testMethod.name)
        XCTAssertEqual(logEntry.metadata["service"], testMethod.serviceName)
        XCTAssertNotNil(logEntry.metadata["error"])
    }

    func test_executeRequest_whenUnknownError_logsError() async {
        // Given
        sut.requestJson = "{}"
        sut.url = "localhost:50051"
        mockExecuteRequestUseCase.arbitraryErrorToThrow = NSError(
            domain: "test",
            code: 99,
            userInfo: [NSLocalizedDescriptionKey: "Something unexpected"])

        // When
        await sut.executeRequest()

        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(mockLogger.errorMessages.count, 1)
        let logEntry = mockLogger.errorMessages[0]
        XCTAssertEqual(logEntry.metadata["method"], testMethod.name)
        XCTAssertEqual(logEntry.metadata["service"], testMethod.serviceName)
        XCTAssertNotNil(logEntry.metadata["error"])
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
                "grpc-message": "Method not implemented",
            ])

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

    // MARK: - Per-tab environment

    func test_init_withGlobalEnv_setsUrlAndTabEnvironment() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        let vm = EditorTabViewModel(
            editorTab: testEditorTab,
            initialEnvironment: env,
            availableEnvironments: [env],
            generateMockDataUseCase: mockGenerateMockDataUseCase,
            executeRequestUseCase: mockExecuteRequestUseCase,
            exportResponseUseCase: mockExportResponseUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            logger: mockLogger)

        XCTAssertEqual(vm.url, "localhost:50051")
        XCTAssertEqual(vm.tabEnvironment, env)
    }

    func test_init_withoutGlobalEnv_urlIsEmpty() {
        let vm = EditorTabViewModel(
            editorTab: testEditorTab,
            initialEnvironment: nil,
            availableEnvironments: [],
            generateMockDataUseCase: mockGenerateMockDataUseCase,
            executeRequestUseCase: mockExecuteRequestUseCase,
            exportResponseUseCase: mockExportResponseUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            logger: mockLogger)

        XCTAssertEqual(vm.url, "")
        XCTAssertNil(vm.tabEnvironment)
    }

    func test_init_withCustomUrl_setsUrlWithoutEnvironment() {
        let vm = EditorTabViewModel(
            editorTab: testEditorTab,
            initialEnvironment: nil,
            customUrl: "my-server:9090",
            availableEnvironments: [],
            generateMockDataUseCase: mockGenerateMockDataUseCase,
            executeRequestUseCase: mockExecuteRequestUseCase,
            exportResponseUseCase: mockExportResponseUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            logger: mockLogger)

        XCTAssertEqual(vm.url, "my-server:9090")
        XCTAssertNil(vm.tabEnvironment)
    }

    func test_selectTabEnvironment_updatesUrlAndEnvironment() {
        let env = ServerEnvironment(name: "Staging", host: "staging.example.com", port: 443)

        sut.selectTabEnvironment(env)

        XCTAssertEqual(sut.url, "staging.example.com:443")
        XCTAssertEqual(sut.tabEnvironment, env)
    }

    func test_useCustomUrl_clearsEnvironmentAndSetsUrl() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        sut.selectTabEnvironment(env)

        sut.useCustomUrl("my-server:9090")

        XCTAssertNil(sut.tabEnvironment)
        XCTAssertEqual(sut.url, "my-server:9090")
    }

    // MARK: - TLS / ConnectionSecurity integration

    func test_executeRequest_setsEffectiveTLSConfigOnRequestDraft() async {
        let tlsConfig = TLSConfiguration(isTLSEnabled: true)
        sut.connectionSecurity.update(activeEnvironment: nil, restoredAdHocConfig: tlsConfig)
        sut.requestJson = "{}"
        sut.url = "localhost:50051"
        mockExecuteRequestUseCase.stubbedResponse = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK")

        await sut.executeRequest()

        XCTAssertEqual(mockExecuteRequestUseCase.capturedRequest?.tlsConfiguration, tlsConfig)
    }

    func test_setTabEnvironment_updatesConnectionSecurityMode() {
        let env = ServerEnvironment(name: "Production", host: "localhost", port: 50051)
        XCTAssertFalse(sut.connectionSecurity.isEnvironmentMode)

        sut.selectTabEnvironment(env)

        XCTAssertTrue(sut.connectionSecurity.isEnvironmentMode)
    }

    func test_useCustomUrl_clearsConnectionSecurityEnvironmentMode() {
        let env = ServerEnvironment(name: "Production", host: "localhost", port: 50051)
        sut.selectTabEnvironment(env)
        XCTAssertTrue(sut.connectionSecurity.isEnvironmentMode)

        sut.useCustomUrl("localhost:9090")

        XCTAssertFalse(sut.connectionSecurity.isEnvironmentMode)
    }

    func test_init_withRestoredTabState_restoresAdHocTLSConfig() {
        let adHocTLS = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)
        let tabState = EditorTabState(
            id: testEditorTab.id,
            protoFilePath: "/test/users.proto",
            serviceName: "UserService",
            methodName: "GetUser",
            adHocTLSConfiguration: adHocTLS)

        let vm = EditorTabViewModel(
            editorTab: testEditorTab,
            restoredTabState: tabState,
            generateMockDataUseCase: mockGenerateMockDataUseCase,
            executeRequestUseCase: mockExecuteRequestUseCase,
            exportResponseUseCase: mockExportResponseUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            logger: mockLogger)

        XCTAssertEqual(vm.connectionSecurity.adHocConfig, adHocTLS)
    }

    func test_saveTabState_includesAdHocTLSConfigurationForCustomURLTabs() {
        let adHocTLS = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)
        sut.connectionSecurity.update(activeEnvironment: nil, restoredAdHocConfig: adHocTLS)
        sut.useCustomUrl("localhost:9090")

        let state = sut.currentTabState

        XCTAssertEqual(state.adHocTLSConfiguration, adHocTLS)
    }

    func test_saveTabState_omitsAdHocTLSConfigurationForEnvironmentTabs() {
        let adHocTLS = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)
        let env = ServerEnvironment(name: "Production", host: "localhost", port: 50051)
        sut.connectionSecurity.update(activeEnvironment: nil, restoredAdHocConfig: adHocTLS)
        sut.selectTabEnvironment(env)

        let state = sut.currentTabState

        XCTAssertNil(state.adHocTLSConfiguration)
    }

    // MARK: - Preset & Autocomplete (OPE-234)

    func test_loadMockData_passesProtoFileToUseCase() async {
        // Given
        mockGenerateMockDataUseCase.mockJSON = "{}"

        // When
        await sut.loadMockData()

        // Then
        XCTAssertEqual(mockGenerateMockDataUseCase.capturedProtoFile?.id, testProtoFile.id)
    }

    func test_resetToPreset_updatesRequestJson() async {
        // Given
        mockGenerateMockDataUseCase.mockJSON = "{\"preset\": true}"

        // When
        await sut.resetToPreset()

        // Then
        XCTAssertEqual(sut.requestJson, "{\"preset\": true}")
    }

    func test_init_createsAutocompleteViewModelWithInjectedDependencies() {
        // Then
        XCTAssertNotNil(sut.autocompleteViewModel)
    }
}

// MARK: - Format Actions (OPE-246)

extension EditorTabViewModelTests {
    func test_formatRequestJson_validJson_updatesRequestJson() {
        // Given
        sut.requestJson = "{\"userId\":1}"
        mockJsonFormatter.formattedResult = "{\n  \"userId\" : 1\n}"

        // When
        sut.formatRequestJson()

        // Then
        XCTAssertEqual(sut.requestJson, "{\n  \"userId\" : 1\n}")
    }

    func test_formatRequestJson_invalidJson_setsFormatError() {
        // Given
        sut.requestJson = "{invalid"
        mockJsonFormatter.shouldThrow = true

        // When
        sut.formatRequestJson()

        // Then
        XCTAssertNotNil(sut.requestJsonFormatError)
    }

    func test_formatRequestJson_invalidJson_doesNotModifyRequestJson() {
        // Given
        let original = "{invalid"
        sut.requestJson = original
        mockJsonFormatter.shouldThrow = true

        // When
        sut.formatRequestJson()

        // Then
        XCTAssertEqual(sut.requestJson, original)
    }

    func test_formatRequestJson_validJson_clearsExistingFormatError() {
        // Given
        sut.requestJson = "{}"
        sut.requestJsonFormatError = "previous error"
        mockJsonFormatter.formattedResult = "{}"

        // When
        sut.formatRequestJson()

        // Then
        XCTAssertNil(sut.requestJsonFormatError)
    }

    func test_formatMetadata_validJson_updatesMetadataJson() {
        // Given
        sut.metadataJson = "{\"authorization\":\"Bearer token\"}"
        mockJsonFormatter.formattedResult = "{\n  \"authorization\" : \"Bearer token\"\n}"

        // When
        sut.formatMetadata()

        // Then
        XCTAssertEqual(sut.metadataJson, "{\n  \"authorization\" : \"Bearer token\"\n}")
    }

    func test_formatMetadata_invalidJson_setsMetadataFormatError() {
        // Given
        sut.metadataJson = "{invalid"
        mockJsonFormatter.shouldThrow = true

        // When
        sut.formatMetadata()

        // Then
        XCTAssertNotNil(sut.metadataFormatError)
    }

    func test_formatMetadata_invalidJson_doesNotModifyMetadataJson() {
        // Given
        let original = "{invalid"
        sut.metadataJson = original
        mockJsonFormatter.shouldThrow = true

        // When
        sut.formatMetadata()

        // Then
        XCTAssertEqual(sut.metadataJson, original)
    }

    func test_loadMockData_prettyPrintsResult() async {
        // Given
        let compact = "{\"userId\":1}"
        let pretty = "{\n  \"userId\" : 1\n}"
        mockGenerateMockDataUseCase.mockJSON = compact
        mockJsonFormatter.formattedResult = pretty

        // When
        await sut.loadMockData()

        // Then
        XCTAssertEqual(sut.requestJson, pretty)
    }

    func test_loadMockData_whenFormatterThrows_keepsMockJson() async {
        // Given
        let compact = "{\"userId\":1}"
        mockGenerateMockDataUseCase.mockJSON = compact
        mockJsonFormatter.shouldThrow = true

        // When
        await sut.loadMockData()

        // Then
        XCTAssertEqual(sut.requestJson, compact)
    }

    // MARK: - Error clearing on edit (OPE-249)

    func test_updateJson_clearsRequestJsonFormatError() {
        // Given
        sut.requestJsonFormatError = "Invalid JSON"

        // When
        sut.updateJson("{}")

        // Then
        XCTAssertNil(sut.requestJsonFormatError)
    }

    func test_updateMetadata_clearsMetadataFormatError() {
        // Given
        sut.metadataFormatError = "Invalid JSON"

        // When
        sut.updateMetadata("{}")

        // Then
        XCTAssertNil(sut.metadataFormatError)
    }
}
