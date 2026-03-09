import XCTest
@testable import TrueRPCMini

final class UserDefaultsTabRepositoryTests: XCTestCase {
    var sut: UserDefaultsTabRepository!
    var userDefaults: UserDefaults!
    let testSuite = "test-tab-repository"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: testSuite)!
        userDefaults.removePersistentDomain(forName: testSuite)
        sut = UserDefaultsTabRepository(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: testSuite)
        sut = nil
        userDefaults = nil
        super.tearDown()
    }

    func test_getTabStates_whenEmpty_returnsEmptyArray() {
        let result = sut.getTabStates()

        XCTAssertTrue(result.isEmpty)
    }

    func test_saveTabStates_storesStates() {
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/path/to/file.proto",
            serviceName: "UserService",
            methodName: "GetUser")

        sut.saveTabStates([state])
        let result = sut.getTabStates()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], state)
    }

    func test_saveTabStates_withMultipleStates_storesAll() {
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

        sut.saveTabStates([state1, state2])
        let result = sut.getTabStates()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], state1)
        XCTAssertEqual(result[1], state2)
    }

    func test_saveTabStates_overwritesPrevious() {
        let original = EditorTabState(
            id: UUID(),
            protoFilePath: "/old.proto",
            serviceName: "Old",
            methodName: "OldMethod")
        sut.saveTabStates([original])

        let replacement = EditorTabState(
            id: UUID(),
            protoFilePath: "/new.proto",
            serviceName: "New",
            methodName: "NewMethod")
        sut.saveTabStates([replacement])

        let result = sut.getTabStates()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], replacement)
    }

    func test_saveTabStates_emptyArray_clearsExisting() {
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/path.proto",
            serviceName: "S",
            methodName: "M")
        sut.saveTabStates([state])

        sut.saveTabStates([])

        XCTAssertTrue(sut.getTabStates().isEmpty)
    }

    func test_persistsAcrossInstances() {
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/path.proto",
            serviceName: "UserService",
            methodName: "GetUser")
        sut.saveTabStates([state])

        let newSut = UserDefaultsTabRepository(userDefaults: userDefaults)
        let result = newSut.getTabStates()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], state)
    }

    func test_saveAndGet_withSelectedEnvironmentId_preservesEnvId() {
        let envId = UUID()
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/path.proto",
            serviceName: "UserService",
            methodName: "GetUser",
            selectedEnvironmentId: envId)
        sut.saveTabStates([state])

        let result = sut.getTabStates()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].selectedEnvironmentId, envId)
    }

    func test_saveAndGet_withCustomUrl_preservesCustomUrl() {
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/path.proto",
            serviceName: "UserService",
            methodName: "GetUser",
            customUrl: "my-server:50051")
        sut.saveTabStates([state])

        let result = sut.getTabStates()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].customUrl, "my-server:50051")
    }
}
