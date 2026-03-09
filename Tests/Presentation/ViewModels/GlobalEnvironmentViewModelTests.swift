import XCTest
@testable import TrueRPCMini

@MainActor
final class GlobalEnvironmentViewModelTests: XCTestCase {
    var sut: GlobalEnvironmentViewModel!
    var mockLoadUseCase: MockLoadEnvironmentsUseCase!
    var mockSaveUseCase: MockSaveEnvironmentUseCase!
    var mockDeleteUseCase: MockDeleteEnvironmentUseCase!
    var mockSelectUseCase: MockSelectEnvironmentUseCase!
    var mockGetSelectedUseCase: MockGetSelectedEnvironmentUseCase!

    override func setUp() {
        super.setUp()
        mockLoadUseCase = MockLoadEnvironmentsUseCase()
        mockSaveUseCase = MockSaveEnvironmentUseCase()
        mockDeleteUseCase = MockDeleteEnvironmentUseCase()
        mockSelectUseCase = MockSelectEnvironmentUseCase()
        mockGetSelectedUseCase = MockGetSelectedEnvironmentUseCase()
    }

    override func tearDown() {
        sut = nil
        mockLoadUseCase = nil
        mockSaveUseCase = nil
        mockDeleteUseCase = nil
        mockSelectUseCase = nil
        mockGetSelectedUseCase = nil
        super.tearDown()
    }

    private func makeSUT() -> GlobalEnvironmentViewModel {
        GlobalEnvironmentViewModel(
            loadEnvironmentsUseCase: mockLoadUseCase,
            saveEnvironmentUseCase: mockSaveUseCase,
            deleteEnvironmentUseCase: mockDeleteUseCase,
            selectEnvironmentUseCase: mockSelectUseCase,
            getSelectedEnvironmentUseCase: mockGetSelectedUseCase)
    }

    // MARK: - init

    func test_init_loadsEnvironments() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockLoadUseCase.stubbedResult = [env]

        sut = makeSUT()

        XCTAssertEqual(sut.environments.count, 1)
        XCTAssertEqual(sut.environments[0], env)
    }

    func test_init_restoresSelectedEnvironment() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockGetSelectedUseCase.stubbedResult = env

        sut = makeSUT()

        XCTAssertEqual(sut.selectedEnvironment, env)
    }

    func test_init_whenNoSelection_selectedEnvironmentIsNil() {
        mockGetSelectedUseCase.stubbedResult = nil

        sut = makeSUT()

        XCTAssertNil(sut.selectedEnvironment)
    }

    // MARK: - selectEnvironment

    func test_selectEnvironment_updatesPublishedProperty() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        sut = makeSUT()

        sut.selectEnvironment(env)

        XCTAssertEqual(sut.selectedEnvironment, env)
    }

    func test_selectEnvironment_persistsSelection() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        sut = makeSUT()

        sut.selectEnvironment(env)

        XCTAssertEqual(mockSelectUseCase.executeCallCount, 1)
        XCTAssertEqual(mockSelectUseCase.lastExecuted as? ServerEnvironment, env)
    }

    // MARK: - clearSelection

    func test_clearSelection_setsNil() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockGetSelectedUseCase.stubbedResult = env
        sut = makeSUT()

        sut.clearSelection()

        XCTAssertNil(sut.selectedEnvironment)
    }

    func test_clearSelection_persistsNil() {
        sut = makeSUT()

        sut.clearSelection()

        XCTAssertEqual(mockSelectUseCase.executeCallCount, 1)
        XCTAssertEqual(mockSelectUseCase.lastExecuted as ServerEnvironment??, .some(nil))
    }

    // MARK: - saveEnvironment

    func test_saveEnvironment_callsSaveUseCase() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        sut = makeSUT()

        sut.saveEnvironment(env)

        XCTAssertEqual(mockSaveUseCase.savedEnvironments, [env])
    }

    func test_saveEnvironment_reloadsEnvironments() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockLoadUseCase.stubbedResult = [env]
        sut = makeSUT()
        mockLoadUseCase.executeCallCount = 0

        sut.saveEnvironment(env)

        XCTAssertEqual(mockLoadUseCase.executeCallCount, 1)
    }

    // MARK: - deleteEnvironment

    func test_deleteEnvironment_callsDeleteUseCase() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        sut = makeSUT()

        sut.deleteEnvironment(env)

        XCTAssertEqual(mockDeleteUseCase.deletedIds, [env.id])
    }

    func test_deleteEnvironment_whenSelected_clearsSelectionAndPersists() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockGetSelectedUseCase.stubbedResult = env
        sut = makeSUT()

        sut.deleteEnvironment(env)

        XCTAssertNil(sut.selectedEnvironment)
        XCTAssertEqual(mockSelectUseCase.executeCallCount, 1)
    }
}
