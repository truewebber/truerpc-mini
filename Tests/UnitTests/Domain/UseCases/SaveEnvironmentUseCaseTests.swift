import XCTest
@testable import TrueRPCMini

final class SaveEnvironmentUseCaseTests: XCTestCase {
    var sut: SaveEnvironmentUseCase!
    var mockRepository: MockEnvironmentRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockEnvironmentRepository()
        sut = SaveEnvironmentUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func test_execute_savesNewEnvironment() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)

        sut.execute(env)

        XCTAssertEqual(mockRepository.savedEnvironments.count, 1)
        XCTAssertEqual(mockRepository.savedEnvironments[0], env)
    }

    func test_execute_updatesExistingEnvironment() {
        let id = UUID()
        let original = ServerEnvironment(id: id, name: "Local", host: "localhost", port: 50051)
        mockRepository.savedEnvironments = [original]
        let updated = ServerEnvironment(id: id, name: "Local Dev", host: "127.0.0.1", port: 8080)

        sut.execute(updated)

        XCTAssertEqual(mockRepository.savedEnvironments.count, 1)
        XCTAssertEqual(mockRepository.savedEnvironments[0], updated)
    }

    func test_execute_saveMultipleEnvironments() {
        let env1 = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        let env2 = ServerEnvironment(name: "Staging", host: "staging.example.com", port: 443)

        sut.execute(env1)
        sut.execute(env2)

        XCTAssertEqual(mockRepository.savedEnvironments.count, 2)
    }
}
