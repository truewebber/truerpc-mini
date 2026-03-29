import SwiftUI
import XCTest
@testable import TrueRPCMini

/// Tests for AppViewModel - main app coordinator
@MainActor
final class AppViewModelTests: XCTestCase {
    fileprivate var sut: AppViewModel!
    fileprivate var createTabUseCase: CreateEditorTabUseCase!
    fileprivate var generateMockDataUseCase: GenerateMockDataUseCase!
    fileprivate var executeRequestUseCase: MockExecuteRequestUseCase!
    fileprivate var exportResponseUseCase: ExportResponseUseCase!
    fileprivate var mockJsonFormatter: MockJsonFormatter!
    fileprivate var mockLogger: MockAppLogger!
    fileprivate var mockTelemetry: MockTelemetryService!

    override func setUp() async throws {
        try await super.setUp()
        createTabUseCase = CreateEditorTabUseCase()
        generateMockDataUseCase = GenerateMockDataUseCase(
            mockDataGenerator: MockDataGenerator(protoRepository: StubProtoRepository()))
        exportResponseUseCase = ExportResponseUseCase(
            fileManager: AppMockFileManager())
        executeRequestUseCase = MockExecuteRequestUseCase()
        mockJsonFormatter = MockJsonFormatter()
        mockLogger = MockAppLogger()
        mockTelemetry = MockTelemetryService()

        let tabRepo = UserDefaultsTabRepository(
            userDefaults: UserDefaults(suiteName: "test-app-view-model")!)
        let tabManager = TabManagerViewModel(
            saveTabStateUseCase: SaveTabStateUseCase(repository: tabRepo),
            restoreTabsUseCase: RestoreTabsUseCase(repository: tabRepo))

        sut = AppViewModel(
            tabManager: tabManager,
            createEditorTabUseCase: createTabUseCase,
            generateMockDataUseCase: generateMockDataUseCase,
            executeRequestUseCase: executeRequestUseCase,
            exportResponseUseCase: exportResponseUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            telemetry: mockTelemetry,
            logger: mockLogger)
    }

    override func tearDown() async throws {
        sut = nil
        createTabUseCase = nil
        generateMockDataUseCase = nil
        executeRequestUseCase = nil
        exportResponseUseCase = nil
        mockJsonFormatter = nil
        mockTelemetry = nil
        mockLogger = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func test_init_selectedTabIsNil() {
        // Then
        XCTAssertNil(sut.selectedEditorTab)
    }

    // MARK: - Open Method

    func test_openMethod_createsAndSetsEditorTabViewModel() {
        // Given
        let method = TrueRPCMini.Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".test.GetUserRequest",
            outputType: ".test.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [service])

        // When
        sut.openMethod(method: method, service: service, protoFile: protoFile)

        // Then
        XCTAssertNotNil(sut.selectedEditorTab)
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.methodName, "GetUser")
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.serviceName, "UserService")
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.protoFile.name, "test.proto")
    }

    func test_openMethod_createsViewModelWithCorrectMethod() {
        // Given
        let method = TrueRPCMini.Method(
            name: "CreateUser",
            serviceName: "UserService",
            inputType: ".test.CreateUserRequest",
            outputType: ".test.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/protos/users.proto"),
            services: [service])

        // When
        sut.openMethod(method: method, service: service, protoFile: protoFile)

        // Then
        XCTAssertNotNil(sut.selectedEditorTab)
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.method.name, "CreateUser")
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.method.inputType, ".test.CreateUserRequest")
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.method.outputType, ".test.User")
    }

    func test_openMethod_viewModelCanUpdateState() throws {
        // Given
        let method = TrueRPCMini.Method(
            name: "DeleteUser",
            serviceName: "UserService",
            inputType: ".test.DeleteUserRequest",
            outputType: ".test.Empty")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/protos/users.proto"),
            services: [service])

        // When
        sut.openMethod(method: method, service: service, protoFile: protoFile)

        // Then - Verify ViewModel is functional
        let tabVM = try XCTUnwrap(sut.selectedEditorTab)

        tabVM.updateJson(#"{"id": 123}"#)
        XCTAssertEqual(tabVM.requestJson, #"{"id": 123}"#)

        tabVM.updateUrl("localhost:9090")
        XCTAssertEqual(tabVM.url, "localhost:9090")
    }

    // MARK: - Lifecycle: onLaunched

    func test_onLaunched_tracksAppLaunchedEvent() async {
        sut.onLaunched()
        await waitForEvent(named: "app_launched")

        let names = mockTelemetry.trackedEvents.map(\.name)
        XCTAssertTrue(names.contains("app_launched"), "onLaunched() must track 'app_launched' event")
    }

    func test_onLaunched_includesAppVersionProperty() async {
        sut.onLaunched()
        await waitForEvent(named: "app_launched")

        let event = mockTelemetry.trackedEvents.first { $0.name == "app_launched" }
        XCTAssertNotNil(event?.properties["app_version"], "app_launched event must include 'app_version'")
    }

    func test_onLaunched_includesOsVersionProperty() async {
        sut.onLaunched()
        await waitForEvent(named: "app_launched")

        let event = mockTelemetry.trackedEvents.first { $0.name == "app_launched" }
        XCTAssertNotNil(event?.properties["os_version"], "app_launched event must include 'os_version'")
    }

    func test_onLaunched_calledOnce_tracksExactlyOneEvent() async {
        sut.onLaunched()
        await waitForEvent(named: "app_launched")

        let launchedEvents = mockTelemetry.trackedEvents.filter { $0.name == "app_launched" }
        XCTAssertEqual(launchedEvents.count, 1, "Exactly one app_launched event should be tracked per call")
    }

    // MARK: - Lifecycle: onScenePhaseChanged

    func test_onScenePhaseChanged_whenBackground_tracksAppBackgroundedEvent() async {
        sut.onScenePhaseChanged(to: .background)
        await waitForEvent(named: "app_backgrounded")

        let names = mockTelemetry.trackedEvents.map(\.name)
        XCTAssertTrue(names.contains("app_backgrounded"), "Scene phase .background must track 'app_backgrounded'")
    }

    func test_onScenePhaseChanged_whenActive_tracksAppForegroundedEvent() async {
        sut.onScenePhaseChanged(to: .active)
        await waitForEvent(named: "app_foregrounded")

        let names = mockTelemetry.trackedEvents.map(\.name)
        XCTAssertTrue(names.contains("app_foregrounded"), "Scene phase .active must track 'app_foregrounded'")
    }

    func test_onScenePhaseChanged_whenInactive_doesNotTrackEvent() async {
        sut.onScenePhaseChanged(to: .inactive)
        // Yield a few times to confirm no event is enqueued
        for _ in 0 ..< 5 {
            await Task.yield()
        }

        XCTAssertTrue(mockTelemetry.trackedEvents.isEmpty, "Scene phase .inactive must not track any event")
    }

    func test_onScenePhaseChanged_background_thenActive_tracksBothEvents() async {
        sut.onScenePhaseChanged(to: .background)
        sut.onScenePhaseChanged(to: .active)
        await waitForEvent(named: "app_backgrounded")
        await waitForEvent(named: "app_foregrounded")

        let names = mockTelemetry.trackedEvents.map(\.name)
        XCTAssertTrue(names.contains("app_backgrounded"))
        XCTAssertTrue(names.contains("app_foregrounded"))
    }

    // MARK: - restoreTabs

    func test_restoreTabs_withSelectedEnvironmentId_setsInitialEnvironment() throws {
        let method = TrueRPCMini.Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".test.GetUserRequest",
            outputType: ".test.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [service])

        let env = ServerEnvironment(id: UUID(), name: "Dev", host: "localhost", port: 50051)
        let tabId = UUID()
        let state = EditorTabState(
            id: tabId,
            protoFilePath: "/test/test.proto",
            serviceName: "UserService",
            methodName: "GetUser",
            selectedEnvironmentId: env.id)

        let tabRepo = try UserDefaultsTabRepository(
            userDefaults: XCTUnwrap(UserDefaults(suiteName: "test-restore-env")))
        tabRepo.saveTabStates([state])

        let tabManager = TabManagerViewModel(
            saveTabStateUseCase: SaveTabStateUseCase(repository: tabRepo),
            restoreTabsUseCase: RestoreTabsUseCase(repository: tabRepo))

        let appVM = AppViewModel(
            tabManager: tabManager,
            createEditorTabUseCase: createTabUseCase,
            generateMockDataUseCase: generateMockDataUseCase,
            executeRequestUseCase: executeRequestUseCase,
            exportResponseUseCase: exportResponseUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            telemetry: mockTelemetry,
            logger: mockLogger)

        appVM.restoreTabs(protoFiles: [protoFile], availableEnvironments: [env])

        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.tabs[0].tabEnvironment?.id, env.id)
        XCTAssertEqual(tabManager.tabs[0].url, env.url)
    }

    func test_restoreTabs_withCustomUrl_restoresCustomUrl() throws {
        let method = TrueRPCMini.Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".test.GetUserRequest",
            outputType: ".test.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [service])

        let customEndpoint = "my-server:9090"
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/test/test.proto",
            serviceName: "UserService",
            methodName: "GetUser",
            selectedEnvironmentId: nil,
            customUrl: customEndpoint)

        let tabRepo = try UserDefaultsTabRepository(
            userDefaults: XCTUnwrap(UserDefaults(suiteName: "test-restore-custom-url")))
        tabRepo.saveTabStates([state])

        let tabManager = TabManagerViewModel(
            saveTabStateUseCase: SaveTabStateUseCase(repository: tabRepo),
            restoreTabsUseCase: RestoreTabsUseCase(repository: tabRepo))

        let appVM = AppViewModel(
            tabManager: tabManager,
            createEditorTabUseCase: createTabUseCase,
            generateMockDataUseCase: generateMockDataUseCase,
            executeRequestUseCase: executeRequestUseCase,
            exportResponseUseCase: exportResponseUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            telemetry: mockTelemetry,
            logger: mockLogger)

        appVM.restoreTabs(protoFiles: [protoFile], availableEnvironments: [])

        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertNil(tabManager.tabs[0].tabEnvironment)
        XCTAssertEqual(tabManager.tabs[0].url, customEndpoint)
    }

    func test_restoreTabs_withAdHocTLSConfiguration_restoresTLSSettings() throws {
        let method = TrueRPCMini.Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".test.GetUserRequest",
            outputType: ".test.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [service])

        let savedTLS = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/test/test.proto",
            serviceName: "UserService",
            methodName: "GetUser",
            selectedEnvironmentId: nil,
            customUrl: "localhost:50051",
            adHocTLSConfiguration: savedTLS)

        let tabRepo = try UserDefaultsTabRepository(
            userDefaults: XCTUnwrap(UserDefaults(suiteName: "test-restore-tls")))
        tabRepo.saveTabStates([state])

        let tabManager = TabManagerViewModel(
            saveTabStateUseCase: SaveTabStateUseCase(repository: tabRepo),
            restoreTabsUseCase: RestoreTabsUseCase(repository: tabRepo))

        let appVM = AppViewModel(
            tabManager: tabManager,
            createEditorTabUseCase: createTabUseCase,
            generateMockDataUseCase: generateMockDataUseCase,
            executeRequestUseCase: executeRequestUseCase,
            exportResponseUseCase: exportResponseUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            telemetry: mockTelemetry,
            logger: mockLogger)

        appVM.restoreTabs(protoFiles: [protoFile], availableEnvironments: [])

        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertEqual(tabManager.tabs[0].connectionSecurity.adHocConfig, savedTLS)
    }

    func test_restoreTabs_whenSavedEnvDeleted_fallsBackToNilEnvironment() throws {
        let method = TrueRPCMini.Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".test.GetUserRequest",
            outputType: ".test.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [service])

        let deletedEnvId = UUID()
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/test/test.proto",
            serviceName: "UserService",
            methodName: "GetUser",
            selectedEnvironmentId: deletedEnvId)

        let tabRepo = try UserDefaultsTabRepository(
            userDefaults: XCTUnwrap(UserDefaults(suiteName: "test-restore-env-deleted")))
        tabRepo.saveTabStates([state])

        let tabManager = TabManagerViewModel(
            saveTabStateUseCase: SaveTabStateUseCase(repository: tabRepo),
            restoreTabsUseCase: RestoreTabsUseCase(repository: tabRepo))

        let appVM = AppViewModel(
            tabManager: tabManager,
            createEditorTabUseCase: createTabUseCase,
            generateMockDataUseCase: generateMockDataUseCase,
            executeRequestUseCase: executeRequestUseCase,
            exportResponseUseCase: exportResponseUseCase,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            telemetry: mockTelemetry,
            logger: mockLogger)

        appVM.restoreTabs(protoFiles: [protoFile], availableEnvironments: [])

        XCTAssertEqual(tabManager.tabs.count, 1)
        XCTAssertNil(tabManager.tabs[0].tabEnvironment)
        XCTAssertEqual(tabManager.tabs[0].url, "")
    }

    // MARK: - Helpers

    /// Polls until the given event name appears in trackedEvents (up to ~1 second).
    private func waitForEvent(named name: String) async {
        for _ in 0 ..< 1000 {
            if mockTelemetry.trackedEvents.contains(where: { $0.name == name }) { return }
            await Task.yield()
        }
    }

    // MARK: - openMethod telemetry

    func test_openMethod_tracksTabSwitchedRequestEvent() async {
        // Given
        let method = TrueRPCMini.Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".test.GetUserRequest",
            outputType: ".test.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [service])

        // When
        sut.openMethod(method: method, service: service, protoFile: protoFile)
        await waitForEvent(named: "tab_switched")

        // Then
        let event = mockTelemetry.trackedEvents.first { $0.name == "tab_switched" }
        XCTAssertEqual(event?.properties["tab_name"], "request")
    }

    func test_openMethod_tracksRequestFormOpenedEvent() async {
        // Given
        let method = TrueRPCMini.Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".test.GetUserRequest",
            outputType: ".test.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [service])

        // When
        sut.openMethod(method: method, service: service, protoFile: protoFile)
        await waitForEvent(named: "request_form_opened")

        // Then
        let event = mockTelemetry.trackedEvents.first { $0.name == "request_form_opened" }
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.properties["has_proto"], "true")
    }

    // MARK: - onProtosTabSelected

    func test_onProtosTabSelected_tracksTabSwitchedWithProtosTabName() async {
        // When
        sut.onProtosTabSelected()
        await waitForEvent(named: "tab_switched")

        // Then
        let event = mockTelemetry.trackedEvents.first { $0.name == "tab_switched" }
        XCTAssertEqual(event?.properties["tab_name"], "protos")
    }

    // MARK: - onSettingsOpened

    func test_onSettingsOpened_tracksTabSwitchedWithSettingsTabName() async {
        // When
        sut.onSettingsOpened()
        await waitForEvent(named: "tab_switched")

        // Then
        let event = mockTelemetry.trackedEvents.first { $0.name == "tab_switched" }
        XCTAssertEqual(event?.properties["tab_name"], "settings")
    }

    func test_openMethod_multipleCalls_replacesSelectedTab() {
        // Given
        let method1 = TrueRPCMini.Method(
            name: "Method1",
            serviceName: "Service1",
            inputType: ".test.Request1",
            outputType: ".test.Response1")
        let service1 = Service(name: "Service1", methods: [method1])
        let protoFile1 = ProtoFile(
            name: "test1.proto",
            path: URL(fileURLWithPath: "/test/test1.proto"),
            services: [service1])

        let method2 = TrueRPCMini.Method(
            name: "Method2",
            serviceName: "Service2",
            inputType: ".test.Request2",
            outputType: ".test.Response2")
        let service2 = Service(name: "Service2", methods: [method2])
        let protoFile2 = ProtoFile(
            name: "test2.proto",
            path: URL(fileURLWithPath: "/test/test2.proto"),
            services: [service2])

        // When
        sut.openMethod(method: method1, service: service1, protoFile: protoFile1)
        let firstTabId = sut.selectedEditorTab?.editorTab.id

        sut.openMethod(method: method2, service: service2, protoFile: protoFile2)
        let secondTabId = sut.selectedEditorTab?.editorTab.id

        // Then
        XCTAssertNotEqual(firstTabId, secondTabId)
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.methodName, "Method2")
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.serviceName, "Service2")
    }
}

// MARK: - Mock Execute Request Use Case

@MainActor
private final class MockExecuteRequestUseCase: ExecuteUnaryRequestUseCaseProtocol {
    func execute(request _: RequestDraft, method _: TrueRPCMini.Method, protoFile _: ProtoFile) throws
        -> GrpcResponse
    {
        GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK")
    }
}

// MARK: - Mock File Manager

private final class AppMockFileManager: FileManagerProtocol {
    func write(_: Data, to _: URL) throws {
        // No-op for testing
    }
}
