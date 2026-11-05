import os
import XCTest
@testable import TrueRPCMini

@MainActor
final class TabManagerViewModelTests: XCTestCase {
    var sut: TabManagerViewModel!
    fileprivate var mockSaveTabState: MockSaveTabStateUseCase!
    fileprivate var mockRestoreTabs: MockRestoreTabsUseCase!
    var mockGenerateMockData: GenerateMockDataUseCase!
    fileprivate var mockExecuteRequest: TabManagerMockExecuteRequestUseCase!
    var mockExportResponse: ExportResponseUseCase!
    var mockJsonFormatter: MockJsonFormatter!
    var mockLogger: MockAppLogger!

    override func setUp() async throws {
        try await super.setUp()
        mockSaveTabState = MockSaveTabStateUseCase()
        mockRestoreTabs = MockRestoreTabsUseCase()
        mockGenerateMockData = GenerateMockDataUseCase(
            mockDataGenerator: MockDataGenerator(protoRepository: StubProtoRepository()))
        mockExecuteRequest = TabManagerMockExecuteRequestUseCase()
        mockExportResponse = ExportResponseUseCase(fileManager: TabManagerMockFileManager())
        mockJsonFormatter = MockJsonFormatter()
        mockLogger = MockAppLogger()
        sut = TabManagerViewModel(
            saveTabStateUseCase: mockSaveTabState,
            restoreTabsUseCase: mockRestoreTabs)
    }

    override func tearDown() async throws {
        sut = nil
        mockSaveTabState = nil
        mockRestoreTabs = nil
        mockGenerateMockData = nil
        mockExecuteRequest = nil
        mockExportResponse = nil
        mockJsonFormatter = nil
        mockLogger = nil
        try await super.tearDown()
    }

    func makeEditorTabViewModel(
        methodName: String = "GetUser",
        serviceName: String = "UserService",
        protoFilePath: String = "/test/test.proto")
        -> EditorTabViewModel
    {
        let method = TrueRPCMini.Method(
            name: methodName,
            serviceName: serviceName,
            inputType: ".test.Request",
            outputType: ".test.Response")
        let service = Service(name: serviceName, methods: [method])
        let protoFileURL = URL(fileURLWithPath: protoFilePath)
        let protoFile = ProtoFile(
            name: protoFileURL.lastPathComponent,
            path: protoFileURL,
            services: [service])
        let editorTab = CreateEditorTabUseCase().execute(method: method, service: service, protoFile: protoFile)
        return EditorTabViewModel(
            editorTab: editorTab,
            generateMockDataUseCase: mockGenerateMockData,
            executeRequestUseCase: mockExecuteRequest,
            exportResponseUseCase: mockExportResponse,
            formatter: mockJsonFormatter,
            autocompleteProvider: MockAutocompleteProvider(),
            resolver: JsonPathResolver(),
            logger: mockLogger)
    }

    func test_init_tabsEmpty() {
        XCTAssertTrue(sut.tabs.isEmpty)
    }

    func test_init_selectedTabIdIsNil() {
        XCTAssertNil(sut.selectedTabId)
    }

    func test_addTab_appendsAndSelects() {
        let tabVM = makeEditorTabViewModel()

        sut.addTab(tabVM)

        XCTAssertEqual(sut.tabs.count, 1)
        XCTAssertEqual(sut.tabs[0].editorTab.id, tabVM.editorTab.id)
        XCTAssertEqual(sut.selectedTabId, tabVM.editorTab.id)
    }

    func test_addTab_callsSaveTabStateUseCase() {
        let tabVM = makeEditorTabViewModel()

        sut.addTab(tabVM)

        XCTAssertEqual(mockSaveTabState.savedStates.count, 1)
        XCTAssertEqual(mockSaveTabState.savedStates[0].first?.methodName, "GetUser")
    }

    func test_addTab_withTabEnvironment_savesSelectedEnvironmentId() {
        let tabVM = makeEditorTabViewModel()
        let env = ServerEnvironment(id: UUID(), name: "Dev", host: "localhost", port: 50051)
        tabVM.selectTabEnvironment(env)

        sut.addTab(tabVM)

        XCTAssertEqual(mockSaveTabState.savedStates.count, 1)
        XCTAssertEqual(mockSaveTabState.savedStates[0].first?.selectedEnvironmentId, env.id)
    }

    func test_save_includesEnvironmentChange_whenUserChangesEnvInTab_thenAddsAnotherTab() {
        let tab1 = makeEditorTabViewModel(methodName: "GetUser")
        let envA = ServerEnvironment(id: UUID(), name: "Dev", host: "localhost", port: 50051)
        let envB = ServerEnvironment(id: UUID(), name: "Staging", host: "staging.local", port: 50052)
        tab1.selectTabEnvironment(envA)

        sut.addTab(tab1)
        mockSaveTabState.savedStates = []

        tab1.selectTabEnvironment(envB)

        let tab2 = makeEditorTabViewModel(methodName: "CreateUser")
        sut.addTab(tab2)

        let savedStates = mockSaveTabState.savedStates.last ?? []
        let tab1State = savedStates.first { $0.methodName == "GetUser" }
        XCTAssertEqual(tab1State?.selectedEnvironmentId, envB.id)
    }

    func test_save_triggered_whenUserChangesCustomUrlInTab() {
        let tabVM = makeEditorTabViewModel()
        sut.addTab(tabVM)
        mockSaveTabState.savedStates = []

        tabVM.updateUrl("custom:9999")

        let deadline = Date().addingTimeInterval(0.5)
        while mockSaveTabState.savedStates.isEmpty, Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        let savedStates = mockSaveTabState.savedStates.last ?? []
        let tabState = savedStates.first
        XCTAssertEqual(tabState?.customUrl, "custom:9999")
    }

    func test_addTab_withCustomUrl_savesCustomUrl() {
        let tabVM = makeEditorTabViewModel()
        tabVM.useCustomUrl("my-server:9090")

        sut.addTab(tabVM)

        XCTAssertEqual(mockSaveTabState.savedStates.count, 1)
        XCTAssertNil(mockSaveTabState.savedStates[0].first?.selectedEnvironmentId)
        XCTAssertEqual(mockSaveTabState.savedStates[0].first?.customUrl, "my-server:9090")
    }

    func test_save_includesEnvironmentChange_whenUserClearsEnvInTab_thenRemovesAnotherTab() {
        let tab1 = makeEditorTabViewModel(methodName: "GetUser")
        let tab2 = makeEditorTabViewModel(methodName: "CreateUser")
        let env = ServerEnvironment(id: UUID(), name: "Dev", host: "localhost", port: 50051)
        tab1.selectTabEnvironment(env)

        sut.addTab(tab1)
        sut.addTab(tab2)
        mockSaveTabState.savedStates = []

        tab1.useCustomUrl("custom:9090")

        sut.removeTab(id: tab2.editorTab.id)

        let savedStates = mockSaveTabState.savedStates.last ?? []
        let tab1State = savedStates.first { $0.methodName == "GetUser" }
        XCTAssertNil(tab1State?.selectedEnvironmentId)
        XCTAssertEqual(tab1State?.customUrl, "custom:9090")
    }

    func test_removeTab_removesAndDeselects() {
        let tabVM = makeEditorTabViewModel()
        sut.addTab(tabVM)
        let id = tabVM.editorTab.id

        sut.removeTab(id: id)

        XCTAssertTrue(sut.tabs.isEmpty)
        XCTAssertNil(sut.selectedTabId)
    }

    func test_removeTab_callsSaveTabStateUseCase() {
        let tabVM = makeEditorTabViewModel()
        sut.addTab(tabVM)
        mockSaveTabState.savedStates = []

        sut.removeTab(id: tabVM.editorTab.id)

        XCTAssertEqual(mockSaveTabState.savedStates.count, 1)
        XCTAssertTrue(mockSaveTabState.savedStates.last?.isEmpty == true)
    }

    func test_selectTab_updatesSelectedTabId() {
        let tab1 = makeEditorTabViewModel(methodName: "M1")
        let tab2 = makeEditorTabViewModel(methodName: "M2")
        sut.addTab(tab1)
        sut.addTab(tab2)

        sut.selectTab(id: tab2.editorTab.id)

        XCTAssertEqual(sut.selectedTabId, tab2.editorTab.id)
    }

    func test_restoredStates_returnsFromRestoreTabsUseCase() {
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/path.proto",
            serviceName: "S",
            methodName: "M")
        mockRestoreTabs.states = [state]

        let result = sut.restoredStates()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], state)
    }

    func test_handleEnvironmentDeleted_switchesTabsUsingThatEnvToCustomUrl() {
        let tab1 = makeEditorTabViewModel(methodName: "GetUser")
        let env = ServerEnvironment(id: UUID(), name: "Staging", host: "staging.local", port: 50052)
        tab1.selectTabEnvironment(env)

        sut.addTab(tab1)
        sut.handleEnvironmentDeleted(env)

        XCTAssertNil(tab1.tabEnvironment)
        XCTAssertEqual(tab1.url, "staging.local:50052")
    }

    func test_handleEnvironmentDeleted_doesNotAffectTabsUsingOtherEnv() {
        let tab1 = makeEditorTabViewModel(methodName: "GetUser")
        let envA = ServerEnvironment(id: UUID(), name: "Dev", host: "localhost", port: 50051)
        let envB = ServerEnvironment(id: UUID(), name: "Staging", host: "staging.local", port: 50052)
        tab1.selectTabEnvironment(envA)

        sut.addTab(tab1)
        sut.handleEnvironmentDeleted(envB)

        XCTAssertEqual(tab1.tabEnvironment?.id, envA.id)
        XCTAssertEqual(tab1.url, "localhost:50051")
    }

    func test_handleEnvironmentUpdated_updatesTabsUsingThatEnv() {
        let originalEnv = ServerEnvironment(
            id: UUID(),
            name: "Staging",
            host: "staging.local",
            port: 50052)
        let tab1 = makeEditorTabViewModel(methodName: "GetUser")
        tab1.selectTabEnvironment(originalEnv)
        sut.addTab(tab1)

        let updatedEnv = ServerEnvironment(
            id: originalEnv.id,
            name: "Staging Updated",
            host: "staging.new",
            port: 50052,
            tlsConfiguration: TLSConfiguration(isTLSEnabled: true))
        sut.handleEnvironmentUpdated(updatedEnv)

        XCTAssertEqual(tab1.tabEnvironment?.name, "Staging Updated")
        XCTAssertEqual(tab1.tabEnvironment?.host, "staging.new")
        XCTAssertEqual(tab1.connectionSecurity.effectiveTLSConfiguration, TLSConfiguration(isTLSEnabled: true))
    }

    func test_handleEnvironmentUpdated_doesNotAffectTabsUsingOtherEnv() {
        let envA = ServerEnvironment(id: UUID(), name: "Dev", host: "localhost", port: 50051)
        let envB = ServerEnvironment(id: UUID(), name: "Staging", host: "staging.local", port: 50052)
        let tab1 = makeEditorTabViewModel(methodName: "GetUser")
        tab1.selectTabEnvironment(envA)
        sut.addTab(tab1)

        let updatedEnvB = ServerEnvironment(
            id: envB.id,
            name: "Staging Updated",
            host: "staging.new",
            port: 9999)
        sut.handleEnvironmentUpdated(updatedEnvB)

        XCTAssertEqual(tab1.tabEnvironment?.id, envA.id)
        XCTAssertEqual(tab1.url, "localhost:50051")
    }

    func test_selectedTab_returnsMatchingViewModel() {
        let tabVM = makeEditorTabViewModel()
        sut.addTab(tabVM)

        XCTAssertEqual(sut.selectedTab?.editorTab.id, tabVM.editorTab.id)
    }

    // MARK: - Selection After Closing

    private func addTabs(_ methodNames: [String], protoFilePath: String = "/test/test.proto")
        -> [EditorTabViewModel]
    {
        methodNames.map { name in
            let tab = makeEditorTabViewModel(methodName: name, protoFilePath: protoFilePath)
            sut.addTab(tab)
            return tab
        }
    }

    func test_removeTab_whenSelectedTabHasRightNeighbor_selectsRightNeighbor() {
        let tabs = addTabs(["A", "B", "C"])
        sut.selectTab(id: tabs[1].editorTab.id)

        sut.removeTab(id: tabs[1].editorTab.id)

        XCTAssertEqual(sut.selectedTabId, tabs[2].editorTab.id)
    }

    func test_removeTab_whenSelectedTabIsLast_selectsLeftNeighbor() {
        let tabs = addTabs(["A", "B", "C"])

        sut.removeTab(id: tabs[2].editorTab.id)

        XCTAssertEqual(sut.selectedTabId, tabs[1].editorTab.id)
    }

    func test_removeTab_whenTabIsNotSelected_keepsSelection() {
        let tabs = addTabs(["A", "B", "C"])

        sut.removeTab(id: tabs[0].editorTab.id)

        XCTAssertEqual(sut.selectedTabId, tabs[2].editorTab.id)
        XCTAssertEqual(sut.tabs.map(\.editorTab.methodName), ["B", "C"])
    }

    func test_removeTab_withUnknownId_doesNotSave() {
        _ = addTabs(["A"])
        mockSaveTabState.savedStates = []

        sut.removeTab(id: UUID())

        XCTAssertTrue(mockSaveTabState.savedStates.isEmpty)
    }

    func test_closeSelectedTab_removesSelectedTab() {
        let tabs = addTabs(["A", "B"])

        sut.closeSelectedTab()

        XCTAssertEqual(sut.tabs.map(\.editorTab.id), [tabs[0].editorTab.id])
        XCTAssertEqual(sut.selectedTabId, tabs[0].editorTab.id)
    }

    func test_closeSelectedTab_withoutSelection_keepsTabs() {
        _ = addTabs(["A"])
        sut.selectTab(id: nil)

        sut.closeSelectedTab()

        XCTAssertEqual(sut.tabs.count, 1)
    }

    // MARK: - Bulk Closing

    func test_removeOtherTabs_keepsOnlyGivenTabAndSelectsIt() {
        let tabs = addTabs(["A", "B", "C"])

        sut.removeOtherTabs(keeping: tabs[1].editorTab.id)

        XCTAssertEqual(sut.tabs.map(\.editorTab.id), [tabs[1].editorTab.id])
        XCTAssertEqual(sut.selectedTabId, tabs[1].editorTab.id)
    }

    func test_removeOtherTabs_savesOnce() {
        let tabs = addTabs(["A", "B", "C"])
        mockSaveTabState.savedStates = []

        sut.removeOtherTabs(keeping: tabs[0].editorTab.id)

        XCTAssertEqual(mockSaveTabState.savedStates.count, 1)
    }

    func test_removeTabsToTheRight_removesLaterTabsAndSelectsGivenTabWhenSelectionWasRemoved() {
        let tabs = addTabs(["A", "B", "C", "D"])

        sut.removeTabsToTheRight(of: tabs[1].editorTab.id)

        XCTAssertEqual(sut.tabs.map(\.editorTab.methodName), ["A", "B"])
        XCTAssertEqual(sut.selectedTabId, tabs[1].editorTab.id)
    }

    func test_removeTabsToTheRight_whenSelectionIsKept_keepsSelection() {
        let tabs = addTabs(["A", "B", "C"])
        sut.selectTab(id: tabs[0].editorTab.id)

        sut.removeTabsToTheRight(of: tabs[1].editorTab.id)

        XCTAssertEqual(sut.selectedTabId, tabs[0].editorTab.id)
    }

    func test_removeTabsInProtoFile_removesOnlyThatContractsTabs() {
        let users = addTabs(["GetUser", "DeleteUser"], protoFilePath: "/protos/users.proto")
        let billing = addTabs(["CreateInvoice"], protoFilePath: "/protos/billing.proto")

        sut.removeTabs(inProtoFileAt: URL(fileURLWithPath: "/protos/users.proto"))

        XCTAssertEqual(sut.tabs.map(\.editorTab.id), [billing[0].editorTab.id])
        XCTAssertFalse(sut.tabs.contains { $0.editorTab.id == users[0].editorTab.id })
    }

    func test_removeTabsInProtoFile_whenSelectedTabIsRemoved_selectsNearestRemainingTabToTheRight() {
        let first = addTabs(["CreateInvoice"], protoFilePath: "/protos/billing.proto")
        let users = addTabs(["GetUser", "DeleteUser"], protoFilePath: "/protos/users.proto")
        let last = addTabs(["ListInvoices"], protoFilePath: "/protos/billing.proto")
        sut.selectTab(id: users[0].editorTab.id)

        sut.removeTabs(inProtoFileAt: URL(fileURLWithPath: "/protos/users.proto"))

        XCTAssertEqual(sut.selectedTabId, last[0].editorTab.id)
        XCTAssertEqual(sut.tabs.map(\.editorTab.id), [first[0].editorTab.id, last[0].editorTab.id])
    }

    // MARK: - Keyboard Navigation

    func test_selectNextTab_selectsTabToTheRight() {
        let tabs = addTabs(["A", "B", "C"])
        sut.selectTab(id: tabs[0].editorTab.id)

        sut.selectNextTab()

        XCTAssertEqual(sut.selectedTabId, tabs[1].editorTab.id)
    }

    func test_selectNextTab_onLastTab_wrapsToFirst() {
        let tabs = addTabs(["A", "B", "C"])

        sut.selectNextTab()

        XCTAssertEqual(sut.selectedTabId, tabs[0].editorTab.id)
    }

    func test_selectPreviousTab_selectsTabToTheLeft() {
        let tabs = addTabs(["A", "B", "C"])

        sut.selectPreviousTab()

        XCTAssertEqual(sut.selectedTabId, tabs[1].editorTab.id)
    }

    func test_selectPreviousTab_onFirstTab_wrapsToLast() {
        let tabs = addTabs(["A", "B", "C"])
        sut.selectTab(id: tabs[0].editorTab.id)

        sut.selectPreviousTab()

        XCTAssertEqual(sut.selectedTabId, tabs[2].editorTab.id)
    }

    func test_selectNextTab_withoutTabs_keepsSelectionEmpty() {
        sut.selectNextTab()

        XCTAssertNil(sut.selectedTabId)
    }

    // MARK: - Focusing Open Tabs

    func test_selectExistingTab_whenMethodIsOpen_selectsItsTabAndReturnsTrue() {
        let tabs = addTabs(["GetUser", "DeleteUser"])

        let found = sut.selectExistingTab(
            methodName: "GetUser",
            serviceName: "UserService",
            protoFilePath: URL(fileURLWithPath: "/test/test.proto"))

        XCTAssertTrue(found)
        XCTAssertEqual(sut.selectedTabId, tabs[0].editorTab.id)
    }

    func test_selectExistingTab_whenMethodIsNotOpen_returnsFalseAndKeepsSelection() {
        let tabs = addTabs(["GetUser"])

        let found = sut.selectExistingTab(
            methodName: "GetUser",
            serviceName: "UserService",
            protoFilePath: URL(fileURLWithPath: "/other/test.proto"))

        XCTAssertFalse(found)
        XCTAssertEqual(sut.selectedTabId, tabs[0].editorTab.id)
    }

    func test_selectExistingTab_whenSelectedTabMatches_keepsSelectedDuplicate() {
        let tabs = addTabs(["GetUser", "GetUser"])

        _ = sut.selectExistingTab(
            methodName: "GetUser",
            serviceName: "UserService",
            protoFilePath: URL(fileURLWithPath: "/test/test.proto"))

        XCTAssertEqual(sut.selectedTabId, tabs[1].editorTab.id)
    }

    func test_selectExistingTab_matchesStandardizedProtoFilePath() {
        let tabs = addTabs(["GetUser"])
        sut.selectTab(id: nil)

        let found = sut.selectExistingTab(
            methodName: "GetUser",
            serviceName: "UserService",
            protoFilePath: URL(fileURLWithPath: "/test/../test/test.proto"))

        XCTAssertTrue(found)
        XCTAssertEqual(sut.selectedTabId, tabs[0].editorTab.id)
    }

    // MARK: - Tab Switcher Data Source

    func test_editorTabs_returnsTabsInOrder() {
        let tabs = addTabs(["A", "B"])

        XCTAssertEqual(sut.editorTabs.map(\.id), tabs.map(\.editorTab.id))
    }
}

private final class MockSaveTabStateUseCase: SaveTabStateUseCaseProtocol, Sendable {
    private struct Storage {
        var savedStates: [[EditorTabState]] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    var savedStates: [[EditorTabState]] {
        get { storage.withLock { $0.savedStates } }
        set { storage.withLock { $0.savedStates = newValue } }
    }

    func execute(_ states: [EditorTabState]) {
        storage.withLock { $0.savedStates.append(states) }
    }
}

private final class TabManagerMockExecuteRequestUseCase: ExecuteUnaryRequestUseCaseProtocol {
    func execute(request _: RequestDraft, method _: TrueRPCMini.Method, protoFile _: ProtoFile) throws
        -> GrpcResponse
    {
        GrpcResponse(jsonBody: "{}", responseTime: 0.1, statusCode: 0, statusMessage: "OK")
    }
}

private final class TabManagerMockFileManager: FileManagerProtocol {
    func write(_: Data, to _: URL) throws {}
}

private final class MockRestoreTabsUseCase: RestoreTabsUseCaseProtocol, Sendable {
    private struct Storage {
        var states: [EditorTabState] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    var states: [EditorTabState] {
        get { storage.withLock { $0.states } }
        set { storage.withLock { $0.states = newValue } }
    }

    func execute() -> [EditorTabState] {
        storage.withLock { $0.states }
    }
}
