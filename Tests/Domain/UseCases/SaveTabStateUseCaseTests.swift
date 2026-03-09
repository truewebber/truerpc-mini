import XCTest
@testable import TrueRPCMini

final class SaveTabStateUseCaseTests: XCTestCase {
    var sut: SaveTabStateUseCase!
    fileprivate var mockRepository: MockTabPersistenceForSave!

    override func setUp() {
        super.setUp()
        mockRepository = MockTabPersistenceForSave()
        sut = SaveTabStateUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func test_execute_savesStatesToRepository() {
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/path/to/file.proto",
            serviceName: "UserService",
            methodName: "GetUser")

        sut.execute([state])

        XCTAssertEqual(mockRepository.savedStates.count, 1)
        XCTAssertEqual(mockRepository.savedStates[0], state)
    }

    func test_execute_withEmptyArray_savesEmpty() {
        sut.execute([])

        XCTAssertTrue(mockRepository.savedStates.isEmpty)
    }

    func test_execute_withMultipleStates_savesAll() {
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

        sut.execute([state1, state2])

        XCTAssertEqual(mockRepository.savedStates.count, 2)
        XCTAssertEqual(mockRepository.savedStates[0], state1)
        XCTAssertEqual(mockRepository.savedStates[1], state2)
    }
}

fileprivate final class MockTabPersistenceForSave: TabPersistenceProtocol {
    var savedStates: [EditorTabState] = []

    func saveTabStates(_ states: [EditorTabState]) {
        savedStates = states
    }

    func getTabStates() -> [EditorTabState] {
        savedStates
    }
}
