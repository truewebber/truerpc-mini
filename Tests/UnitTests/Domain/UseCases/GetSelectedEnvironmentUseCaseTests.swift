import XCTest
@testable import TrueRPCMini

final class GetSelectedEnvironmentUseCaseTests: XCTestCase {
    var sut: GetSelectedEnvironmentUseCase!
    var mockRepository: MockEnvironmentRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockEnvironmentRepository()
        sut = GetSelectedEnvironmentUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func test_execute_whenNoSelection_returnsNil() {
        mockRepository.selectedId = nil

        let result = sut.execute()

        XCTAssertNil(result)
    }

    func test_execute_whenSelectionExists_returnsMatchingEnvironment() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockRepository.stubbedGetAll = [env]
        mockRepository.selectedId = env.id

        let result = sut.execute()

        XCTAssertEqual(result, env)
    }

    func test_execute_whenSelectedIdNotInList_returnsNil() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockRepository.stubbedGetAll = [env]
        mockRepository.selectedId = UUID()

        let result = sut.execute()

        XCTAssertNil(result)
    }
}
