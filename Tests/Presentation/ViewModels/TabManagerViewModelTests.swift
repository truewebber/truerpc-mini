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
    var mockLogger: MockAppLogger!

    override func setUp() {
        super.setUp()
        mockSaveTabState = MockSaveTabStateUseCase()
        mockRestoreTabs = MockRestoreTabsUseCase()
        mockGenerateMockData = GenerateMockDataUseCase(mockDataGenerator: MockDataGenerator())
        mockExecuteRequest = TabManagerMockExecuteRequestUseCase()
        mockExportResponse = ExportResponseUseCase(fileManager: TabManagerMockFileManager())
        mockLogger = MockAppLogger()
        sut = TabManagerViewModel(
            saveTabStateUseCase: mockSaveTabState,
            restoreTabsUseCase: mockRestoreTabs)
    }

    override func tearDown() {
        sut = nil
        mockSaveTabState = nil
        mockRestoreTabs = nil
        mockGenerateMockData = nil
        mockExecuteRequest = nil
        mockExportResponse = nil
        mockLogger = nil
        super.tearDown()
    }

    func makeEditorTabViewModel(
        methodName: String = "GetUser",
        serviceName: String = "UserService")
        -> EditorTabViewModel
    {
        let method = TrueRPCMini.Method(
            name: methodName,
            serviceName: serviceName,
            inputType: ".test.Request",
            outputType: ".test.Response")
        let service = Service(name: serviceName, methods: [method])
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [service])
        let editorTab = CreateEditorTabUseCase().execute(method: method, service: service, protoFile: protoFile)
        return EditorTabViewModel(
            editorTab: editorTab,
            generateMockDataUseCase: mockGenerateMockData,
            executeRequestUseCase: mockExecuteRequest,
            exportResponseUseCase: mockExportResponse,
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

    func test_selectedTab_returnsMatchingViewModel() {
        let tabVM = makeEditorTabViewModel()
        sut.addTab(tabVM)

        XCTAssertEqual(sut.selectedTab?.editorTab.id, tabVM.editorTab.id)
    }
}

private final class MockSaveTabStateUseCase: SaveTabStateUseCaseProtocol {
    var savedStates: [[EditorTabState]] = []

    func execute(_ states: [EditorTabState]) {
        savedStates.append(states)
    }
}

private final class TabManagerMockExecuteRequestUseCase: ExecuteUnaryRequestUseCaseProtocol {
    func execute(request _: RequestDraft, method _: TrueRPCMini.Method) throws -> GrpcResponse {
        GrpcResponse(jsonBody: "{}", responseTime: 0.1, statusCode: 0, statusMessage: "OK")
    }
}

private final class TabManagerMockFileManager: FileManagerProtocol {
    func write(_: Data, to _: URL) throws {}
}

private final class MockRestoreTabsUseCase: RestoreTabsUseCaseProtocol {
    var states: [EditorTabState] = []

    func execute() -> [EditorTabState] {
        states
    }
}
