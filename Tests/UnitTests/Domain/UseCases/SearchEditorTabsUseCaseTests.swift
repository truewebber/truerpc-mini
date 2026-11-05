import XCTest
@testable import TrueRPCMini

final class SearchEditorTabsUseCaseTests: XCTestCase {
    private var sut: SearchEditorTabsUseCase!

    private let users = ProtoFile(
        name: "users.proto",
        path: URL(fileURLWithPath: "/protos/users.proto"),
        services: [])
    private let billing = ProtoFile(
        name: "billing.proto",
        path: URL(fileURLWithPath: "/protos/billing.proto"),
        services: [])

    override func setUp() {
        super.setUp()
        sut = SearchEditorTabsUseCase()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    private func makeTab(_ methodName: String, _ serviceName: String, in protoFile: ProtoFile) -> EditorTab {
        EditorTab(
            methodName: methodName,
            serviceName: serviceName,
            protoFile: protoFile,
            method: Method(name: methodName, serviceName: serviceName, inputType: ".In", outputType: ".Out"))
    }

    // MARK: - Grouping

    func test_execute_withEmptyQuery_returnsEveryTabGroupedByProtoFile() {
        let getUser = makeTab("GetUser", "UserService", in: users)
        let createInvoice = makeTab("CreateInvoice", "InvoiceService", in: billing)

        let groups = sut.execute(tabs: [getUser, createInvoice], query: "")

        XCTAssertEqual(groups.map(\.protoFileName), ["billing.proto", "users.proto"])
        XCTAssertEqual(groups.map { $0.tabs.map(\.id) }, [[createInvoice.id], [getUser.id]])
    }

    func test_execute_ordersGroupsByFileNameAndKeepsTabOrderInsideGroup() {
        let getUser = makeTab("GetUser", "UserService", in: users)
        let createInvoice = makeTab("CreateInvoice", "InvoiceService", in: billing)
        let deleteUser = makeTab("DeleteUser", "UserService", in: users)

        let groups = sut.execute(tabs: [getUser, createInvoice, deleteUser], query: "")

        XCTAssertEqual(groups.map(\.protoFilePath), [billing.path, users.path])
        XCTAssertEqual(groups[1].tabs.map(\.id), [getUser.id, deleteUser.id])
    }

    func test_execute_withSameFileNameInDifferentFolders_keepsSeparateGroupsOrderedByPath() {
        let usersV2 = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/protos/v2/users.proto"),
            services: [])
        let getUserV2 = makeTab("GetUser", "UserService", in: usersV2)
        let getUser = makeTab("GetUser", "UserService", in: users)

        let groups = sut.execute(tabs: [getUserV2, getUser], query: "")

        XCTAssertEqual(groups.map(\.protoFilePath), [users.path, usersV2.path])
    }

    func test_execute_withWhitespaceOnlyQuery_returnsEveryTab() {
        let getUser = makeTab("GetUser", "UserService", in: users)

        let groups = sut.execute(tabs: [getUser], query: "   ")

        XCTAssertEqual(groups.flatMap(\.tabs).map(\.id), [getUser.id])
    }

    // MARK: - Matching

    func test_execute_matchesMethodNameIgnoringCase() {
        let getUser = makeTab("GetUser", "UserService", in: users)
        let createInvoice = makeTab("CreateInvoice", "InvoiceService", in: billing)

        let groups = sut.execute(tabs: [getUser, createInvoice], query: "getuser")

        XCTAssertEqual(groups.flatMap(\.tabs).map(\.id), [getUser.id])
    }

    func test_execute_matchesServiceName() {
        let getUser = makeTab("GetUser", "UserService", in: users)
        let createInvoice = makeTab("CreateInvoice", "InvoiceService", in: billing)

        let groups = sut.execute(tabs: [getUser, createInvoice], query: "invoiceserv")

        XCTAssertEqual(groups.flatMap(\.tabs).map(\.id), [createInvoice.id])
    }

    func test_execute_matchesProtoFileName() {
        let getUser = makeTab("GetUser", "UserService", in: users)
        let createInvoice = makeTab("CreateInvoice", "InvoiceService", in: billing)

        let groups = sut.execute(tabs: [getUser, createInvoice], query: "billing")

        XCTAssertEqual(groups.map(\.protoFilePath), [billing.path])
    }

    func test_execute_withSeveralWords_requiresEveryWordToMatch() {
        let getUser = makeTab("GetUser", "UserService", in: users)
        let getInvoice = makeTab("GetInvoice", "InvoiceService", in: billing)

        let groups = sut.execute(tabs: [getUser, getInvoice], query: "get invoice")

        XCTAssertEqual(groups.flatMap(\.tabs).map(\.id), [getInvoice.id])
    }

    func test_execute_withServiceDotMethodQuery_matchesThatMethod() {
        let getUser = makeTab("GetUser", "UserService", in: users)
        let deleteUser = makeTab("DeleteUser", "UserService", in: users)

        let groups = sut.execute(tabs: [getUser, deleteUser], query: "UserService.Delete")

        XCTAssertEqual(groups.flatMap(\.tabs).map(\.id), [deleteUser.id])
    }

    func test_execute_dropsGroupsWithoutMatchingTabs() {
        let getUser = makeTab("GetUser", "UserService", in: users)
        let createInvoice = makeTab("CreateInvoice", "InvoiceService", in: billing)

        let groups = sut.execute(tabs: [getUser, createInvoice], query: "user")

        XCTAssertEqual(groups.map(\.protoFilePath), [users.path])
    }

    func test_execute_whenNothingMatches_returnsNoGroups() {
        let getUser = makeTab("GetUser", "UserService", in: users)

        let groups = sut.execute(tabs: [getUser], query: "payments")

        XCTAssertTrue(groups.isEmpty)
    }
}
