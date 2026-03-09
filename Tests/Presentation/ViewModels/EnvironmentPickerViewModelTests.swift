import XCTest
@testable import TrueRPCMini

@MainActor
final class EnvironmentPickerViewModelTests: XCTestCase {
    var sut: EnvironmentPickerViewModel!
    var mockLoadUseCase: MockLoadEnvironmentsUseCase!
    var mockSaveUseCase: MockSaveEnvironmentUseCase!
    var mockDeleteUseCase: MockDeleteEnvironmentUseCase!

    override func setUp() {
        super.setUp()
        mockLoadUseCase = MockLoadEnvironmentsUseCase()
        mockSaveUseCase = MockSaveEnvironmentUseCase()
        mockDeleteUseCase = MockDeleteEnvironmentUseCase()
        sut = EnvironmentPickerViewModel(
            loadEnvironmentsUseCase: mockLoadUseCase,
            saveEnvironmentUseCase: mockSaveUseCase,
            deleteEnvironmentUseCase: mockDeleteUseCase)
    }

    override func tearDown() {
        sut = nil
        mockLoadUseCase = nil
        mockSaveUseCase = nil
        mockDeleteUseCase = nil
        super.tearDown()
    }

    // MARK: - loadEnvironments

    func test_loadEnvironments_populatesEnvironments() {
        let env1 = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        let env2 = ServerEnvironment(name: "Staging", host: "staging.example.com", port: 443)
        mockLoadUseCase.stubbedResult = [env1, env2]

        sut.loadEnvironments()

        XCTAssertEqual(sut.environments.count, 2)
        XCTAssertEqual(sut.environments[0], env1)
        XCTAssertEqual(sut.environments[1], env2)
    }

    func test_loadEnvironments_whenEmpty_setsEmptyArray() {
        mockLoadUseCase.stubbedResult = []

        sut.loadEnvironments()

        XCTAssertTrue(sut.environments.isEmpty)
    }

    // MARK: - saveEnvironment

    func test_saveEnvironment_callsSaveUseCase() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)

        sut.saveEnvironment(env)

        XCTAssertEqual(mockSaveUseCase.savedEnvironments.count, 1)
        XCTAssertEqual(mockSaveUseCase.savedEnvironments[0], env)
    }

    func test_saveEnvironment_reloadsEnvironments() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockLoadUseCase.stubbedResult = [env]

        sut.saveEnvironment(env)

        XCTAssertEqual(mockLoadUseCase.executeCallCount, 1)
        XCTAssertEqual(sut.environments.count, 1)
    }

    // MARK: - deleteEnvironment

    func test_deleteEnvironment_callsDeleteUseCase() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)

        sut.deleteEnvironment(env)

        XCTAssertEqual(mockDeleteUseCase.deletedIds, [env.id])
    }

    func test_deleteEnvironment_reloadsEnvironments() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockLoadUseCase.stubbedResult = []

        sut.deleteEnvironment(env)

        XCTAssertEqual(mockLoadUseCase.executeCallCount, 1)
        XCTAssertTrue(sut.environments.isEmpty)
    }

    func test_deleteEnvironment_whenSelected_clearsSelection() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockLoadUseCase.stubbedResult = [env]
        sut.loadEnvironments()
        sut.selectEnvironment(env)

        sut.deleteEnvironment(env)

        XCTAssertNil(sut.selectedEnvironment)
    }

    // MARK: - selectEnvironment

    func test_selectEnvironment_updatesSelectedEnvironment() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)

        sut.selectEnvironment(env)

        XCTAssertEqual(sut.selectedEnvironment, env)
    }

    func test_selectEnvironment_canChangeSelection() {
        let env1 = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        let env2 = ServerEnvironment(name: "Staging", host: "staging.example.com", port: 443)
        sut.selectEnvironment(env1)

        sut.selectEnvironment(env2)

        XCTAssertEqual(sut.selectedEnvironment, env2)
    }
}
