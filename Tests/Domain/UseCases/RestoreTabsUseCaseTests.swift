import XCTest
@testable import TrueRPCMini

final class RestoreTabsUseCaseTests: XCTestCase {
    var sut: RestoreTabsUseCase!
    fileprivate var mockRepository: MockTabPersistenceForRestore!

    override func setUp() {
        super.setUp()
        mockRepository = MockTabPersistenceForRestore()
        sut = RestoreTabsUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func test_execute_whenRepositoryHasStates_returnsStates() {
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/path/to/file.proto",
            serviceName: "UserService",
            methodName: "GetUser")
        mockRepository.storedStates = [state]

        let result = sut.execute()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], state)
    }

    func test_execute_whenRepositoryEmpty_returnsEmptyArray() {
        mockRepository.storedStates = []

        let result = sut.execute()

        XCTAssertTrue(result.isEmpty)
    }

    func test_execute_withMultipleStates_returnsAll() {
        let state1 = EditorTabState(
            id: UUID(),
            protoFilePath: "/a.proto",
            serviceName: "S1",
            methodName: "M1")
        let state2 = EditorTabState(
            id: UUID(),
            protoFilePath: "/b.proto",
            serviceName: "S2",
            methodName: "M2")
        mockRepository.storedStates = [state1, state2]

        let result = sut.execute()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], state1)
        XCTAssertEqual(result[1], state2)
    }

    func test_execute_callsGetTabStatesOnRepository() {
        _ = sut.execute()

        XCTAssertTrue(mockRepository.getTabStatesCalled)
    }
}

private final class MockTabPersistenceForRestore: TabPersistenceProtocol {
    var storedStates: [EditorTabState] = []
    var getTabStatesCalled = false

    func saveTabStates(_: [EditorTabState]) {}

    func getTabStates() -> [EditorTabState] {
        getTabStatesCalled = true
        return storedStates
    }
}
