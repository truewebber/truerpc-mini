import XCTest
@testable import TrueRPCMini

final class LoadEnvironmentsUseCaseTests: XCTestCase {
    var sut: LoadEnvironmentsUseCase!
    var mockRepository: MockEnvironmentRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockEnvironmentRepository()
        sut = LoadEnvironmentsUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func test_execute_whenRepositoryIsEmpty_returnsEmptyArray() {
        mockRepository.stubbedGetAll = []

        let result = sut.execute()

        XCTAssertTrue(result.isEmpty)
    }

    func test_execute_whenRepositoryHasEnvironments_returnsAll() {
        let env1 = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        let env2 = ServerEnvironment(name: "Staging", host: "staging.example.com", port: 443)
        mockRepository.stubbedGetAll = [env1, env2]

        let result = sut.execute()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], env1)
        XCTAssertEqual(result[1], env2)
    }

    func test_execute_delegatesToRepository() {
        let env = ServerEnvironment(name: "Prod", host: "prod.example.com", port: 443)
        mockRepository.stubbedGetAll = [env]

        _ = sut.execute()

        XCTAssertEqual(mockRepository.stubbedGetAll.count, 1)
    }
}
