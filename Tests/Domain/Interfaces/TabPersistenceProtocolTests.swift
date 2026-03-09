import XCTest
@testable import TrueRPCMini

final class TabPersistenceProtocolTests: XCTestCase {
    func test_mockTabPersistence_saveAndGet_roundtripsData() {
        let mock = MockTabPersistence()
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/path/to/file.proto",
            serviceName: "UserService",
            methodName: "GetUser")

        mock.saveTabStates([state])
        let loaded = mock.getTabStates()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0], state)
    }

    func test_mockTabPersistence_getWhenEmpty_returnsEmpty() {
        let mock = MockTabPersistence()

        let loaded = mock.getTabStates()

        XCTAssertTrue(loaded.isEmpty)
    }
}

private final class MockTabPersistence: TabPersistenceProtocol {
    private var states: [EditorTabState] = []

    func saveTabStates(_ states: [EditorTabState]) {
        self.states = states
    }

    func getTabStates() -> [EditorTabState] {
        states
    }
}
