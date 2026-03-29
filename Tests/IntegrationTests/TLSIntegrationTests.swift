import os
import XCTest
@testable import TrueRPCMini

/// End-to-end integration tests verifying TLS configuration flows correctly
/// from EditorTabViewModel through ExecuteUnaryRequestUseCase to GrpcClientProtocol,
/// and that EditorTabState round-trip via UserDefaultsTabRepository preserves adHocTLSConfiguration.
@MainActor
final class TLSIntegrationTests: XCTestCase {
    var testMethod: TrueRPCMini.Method!
    var testService: Service!
    var testProtoFile: ProtoFile!
    var testEditorTab: EditorTab!
    var spyGrpcClient: SpyGrpcClient!
    var mockTelemetry: MockTelemetryService!
    var executeUseCase: ExecuteUnaryRequestUseCase!
    var mockGenerateMock: MockGenerateMockDataUseCase!
    var mockExport: MockExportResponseUseCase!
    var mockLogger: MockAppLogger!

    override func setUp() async throws {
        try await super.setUp()

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

        spyGrpcClient = SpyGrpcClient()
        mockTelemetry = MockTelemetryService()
        executeUseCase = ExecuteUnaryRequestUseCase(
            grpcClient: spyGrpcClient,
            telemetry: mockTelemetry)
        mockGenerateMock = MockGenerateMockDataUseCase()
        mockExport = MockExportResponseUseCase()
        mockLogger = MockAppLogger()
    }

    override func tearDown() async throws {
        testMethod = nil
        testService = nil
        testProtoFile = nil
        testEditorTab = nil
        spyGrpcClient = nil
        mockTelemetry = nil
        executeUseCase = nil
        mockGenerateMock = nil
        mockExport = nil
        mockLogger = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeVM(
        initialEnvironment: ServerEnvironment? = nil,
        restoredTabState: EditorTabState? = nil)
        -> EditorTabViewModel
    {
        EditorTabViewModel(
            editorTab: testEditorTab,
            initialEnvironment: initialEnvironment,
            restoredTabState: restoredTabState,
            generateMockDataUseCase: mockGenerateMock,
            executeRequestUseCase: executeUseCase,
            exportResponseUseCase: mockExport,
            formatter: JsonFormatter(),
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            logger: mockLogger)
    }

    // MARK: - Integration Tests

    func test_integration_executeRequest_withEnvironmentTLS_sendsTLSConfig() async {
        let tlsConfig = TLSConfiguration(isTLSEnabled: true)
        let env = ServerEnvironment(
            name: "Production",
            host: "prod.example.com",
            port: 443,
            tlsConfiguration: tlsConfig)
        let vm = makeVM(initialEnvironment: env)
        vm.requestJson = "{}"

        await vm.executeRequest()

        XCTAssertEqual(spyGrpcClient.capturedRequest?.tlsConfiguration, tlsConfig)
    }

    func test_integration_executeRequest_withAdHocInsecure_sendsInsecureConfig() async {
        let vm = makeVM()
        vm.requestJson = "{}"
        vm.url = "localhost:50051"
        let insecureConfig = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)
        vm.connectionSecurity.update(activeEnvironment: nil, restoredAdHocConfig: insecureConfig)

        await vm.executeRequest()

        XCTAssertEqual(spyGrpcClient.capturedRequest?.tlsConfiguration, insecureConfig)
    }

    func test_integration_executeRequest_withDefaultConfig_sendsDefaultTLSConfig() async {
        let vm = makeVM()
        vm.requestJson = "{}"
        vm.url = "localhost:50051"

        await vm.executeRequest()

        XCTAssertEqual(spyGrpcClient.capturedRequest?.tlsConfiguration, .defaults)
    }

    func test_integration_switchEnvironment_updatesEffectiveTLS() {
        let vm = makeVM()
        XCTAssertEqual(vm.connectionSecurity.effectiveTLSConfiguration, .defaults)

        let tlsConfig = TLSConfiguration(isTLSEnabled: true)
        let env = ServerEnvironment(
            name: "Staging",
            host: "staging.example.com",
            port: 443,
            tlsConfiguration: tlsConfig)

        vm.selectTabEnvironment(env)

        XCTAssertEqual(vm.connectionSecurity.effectiveTLSConfiguration, tlsConfig)
    }

    func test_integration_tabState_roundTrip_preservesAdHocTLSConfig() throws {
        let suiteName = "test-tls-integration-roundtrip"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let repository = UserDefaultsTabRepository(userDefaults: userDefaults)
        let adHocTLS = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)

        let vm = makeVM()
        vm.connectionSecurity.update(activeEnvironment: nil, restoredAdHocConfig: adHocTLS)
        vm.useCustomUrl("localhost:9090")

        repository.saveTabStates([vm.currentTabState])

        let restoredStates = repository.getTabStates()

        XCTAssertEqual(restoredStates.count, 1)
        XCTAssertEqual(restoredStates[0].adHocTLSConfiguration, adHocTLS)
    }
}

// MARK: - SpyGrpcClient

/// @unchecked Sendable: all mutations serialised on `storage` lock
final class SpyGrpcClient: GrpcClientProtocol, Sendable {
    private struct Storage {
        var capturedRequest: RequestDraft?
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    var capturedRequest: RequestDraft? {
        storage.withLock { $0.capturedRequest }
    }

    func executeUnary(
        request: RequestDraft,
        method _: TrueRPCMini.Method,
        protoFile _: ProtoFile)
        throws -> GrpcResponse
    {
        storage.withLock { $0.capturedRequest = request }
        return GrpcResponse(jsonBody: "{}", responseTime: 0.01, statusCode: 0, statusMessage: "OK")
    }
}
