import XCTest
@testable import TrueRPCMini

@MainActor
final class TabSwitcherViewModelTests: XCTestCase {
    private var sut: TabSwitcherViewModel!
    private var dataSource: MockTabSwitcherDataSource!

    private let users = ProtoFile(
        name: "users.proto",
        path: URL(fileURLWithPath: "/protos/users.proto"),
        services: [])
    private let billing = ProtoFile(
        name: "billing.proto",
        path: URL(fileURLWithPath: "/protos/billing.proto"),
        services: [])

    private var getUser: EditorTab!
    private var deleteUser: EditorTab!
    private var createInvoice: EditorTab!

    override func setUp() async throws {
        try await super.setUp()
        getUser = makeTab("GetUser", "UserService", in: users)
        createInvoice = makeTab("CreateInvoice", "InvoiceService", in: billing)
        deleteUser = makeTab("DeleteUser", "UserService", in: users)
        dataSource = MockTabSwitcherDataSource(tabs: [getUser, createInvoice, deleteUser])
        dataSource.selectedTabId = createInvoice.id
        sut = TabSwitcherViewModel(dataSource: dataSource, searchEditorTabsUseCase: SearchEditorTabsUseCase())
    }

    override func tearDown() async throws {
        sut = nil
        dataSource = nil
        getUser = nil
        deleteUser = nil
        createInvoice = nil
        try await super.tearDown()
    }

    private func makeTab(_ methodName: String, _ serviceName: String, in protoFile: ProtoFile) -> EditorTab {
        EditorTab(
            methodName: methodName,
            serviceName: serviceName,
            protoFile: protoFile,
            method: TrueRPCMini.Method(
                name: methodName,
                serviceName: serviceName,
                inputType: ".In",
                outputType: ".Out"))
    }

    // MARK: - Presenting

    func test_init_isNotPresented() {
        XCTAssertFalse(sut.isPresented)
        XCTAssertTrue(sut.groups.isEmpty)
    }

    func test_present_listsEveryTabGroupedByContractAndHighlightsSelectedTab() {
        sut.present()

        XCTAssertTrue(sut.isPresented)
        XCTAssertEqual(sut.groups.map(\.protoFileName), ["billing.proto", "users.proto"])
        XCTAssertEqual(sut.highlightedTabID, createInvoice.id)
    }

    func test_present_clearsPreviousQuery() {
        sut.present()
        sut.query = "invoice"
        sut.dismiss()

        sut.present()

        XCTAssertEqual(sut.query, "")
        XCTAssertEqual(sut.groups.flatMap(\.tabs).count, 3)
    }

    func test_present_withoutSelectedTab_highlightsFirstRow() {
        dataSource.selectedTabId = nil

        sut.present()

        XCTAssertEqual(sut.highlightedTabID, createInvoice.id)
    }

    func test_togglePresentation_presentsThenDismisses() {
        sut.togglePresentation()
        XCTAssertTrue(sut.isPresented)

        sut.togglePresentation()
        XCTAssertFalse(sut.isPresented)
    }

    func test_totalTabCount_returnsNumberOfOpenTabs() {
        XCTAssertEqual(sut.totalTabCount, 3)
    }

    // MARK: - Searching

    func test_query_filtersTabsAndHighlightsFirstMatch() {
        sut.present()

        sut.query = "user"

        XCTAssertEqual(sut.groups.flatMap(\.tabs).map(\.id), [getUser.id, deleteUser.id])
        XCTAssertEqual(sut.highlightedTabID, getUser.id)
    }

    func test_query_withoutMatches_clearsHighlight() {
        sut.present()

        sut.query = "payments"

        XCTAssertTrue(sut.groups.isEmpty)
        XCTAssertNil(sut.highlightedTabID)
    }

    // MARK: - Keyboard Navigation

    func test_moveHighlight_movesAcrossGroupsInListOrder() {
        sut.present()

        sut.moveHighlight(by: 1)
        XCTAssertEqual(sut.highlightedTabID, getUser.id)

        sut.moveHighlight(by: 1)
        XCTAssertEqual(sut.highlightedTabID, deleteUser.id)
    }

    func test_moveHighlight_stopsAtEnds() {
        sut.present()

        sut.moveHighlight(by: 10)
        XCTAssertEqual(sut.highlightedTabID, deleteUser.id)

        sut.moveHighlight(by: -10)
        XCTAssertEqual(sut.highlightedTabID, createInvoice.id)
    }

    func test_activateHighlightedTab_selectsItAndDismisses() {
        sut.present()
        sut.highlight(tabID: deleteUser.id)

        sut.activateHighlightedTab()

        XCTAssertEqual(dataSource.selectedTabId, deleteUser.id)
        XCTAssertFalse(sut.isPresented)
    }

    func test_activateHighlightedTab_withoutHighlight_staysPresented() {
        sut.present()
        sut.query = "payments"

        sut.activateHighlightedTab()

        XCTAssertEqual(dataSource.selectedTabId, createInvoice.id)
        XCTAssertTrue(sut.isPresented)
    }

    func test_activateTab_selectsGivenTabAndDismisses() {
        sut.present()

        sut.activate(tabID: getUser.id)

        XCTAssertEqual(dataSource.selectedTabId, getUser.id)
        XCTAssertFalse(sut.isPresented)
    }

    // MARK: - Closing

    func test_closeTab_removesTabAndKeepsSwitcherOpen() {
        sut.present()

        sut.closeTab(id: getUser.id)

        XCTAssertEqual(dataSource.removedTabIDs, [getUser.id])
        XCTAssertEqual(sut.groups.flatMap(\.tabs).map(\.id), [createInvoice.id, deleteUser.id])
        XCTAssertTrue(sut.isPresented)
    }

    func test_closeTab_whenHighlighted_highlightsTabThatTookItsPlace() {
        sut.present()
        sut.highlight(tabID: getUser.id)

        sut.closeTab(id: getUser.id)

        XCTAssertEqual(sut.highlightedTabID, deleteUser.id)
    }

    func test_closeTab_whenLastRowIsHighlighted_highlightsNewLastRow() {
        sut.present()
        sut.highlight(tabID: deleteUser.id)

        sut.closeTab(id: deleteUser.id)

        XCTAssertEqual(sut.highlightedTabID, getUser.id)
    }

    func test_closeTab_whenAnotherTabIsHighlighted_keepsHighlight() {
        sut.present()

        sut.closeTab(id: getUser.id)

        XCTAssertEqual(sut.highlightedTabID, createInvoice.id)
    }
}

@MainActor
private final class MockTabSwitcherDataSource: TabSwitcherDataSource {
    private(set) var editorTabs: [EditorTab]
    var selectedTabId: UUID?
    private(set) var removedTabIDs: [UUID] = []

    init(tabs: [EditorTab]) {
        self.editorTabs = tabs
    }

    func selectTab(id: UUID?) {
        selectedTabId = id
    }

    func removeTab(id: UUID) {
        removedTabIDs.append(id)
        editorTabs.removeAll { $0.id == id }
    }
}
