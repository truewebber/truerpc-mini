import XCTest
@testable import TrueRPCMini

final class DeleteEnvironmentUseCaseTests: XCTestCase {
    var sut: DeleteEnvironmentUseCase!
    var mockRepository: MockEnvironmentRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockEnvironmentRepository()
        sut = DeleteEnvironmentUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func test_execute_deletesEnvironmentById() {
        let id = UUID()
        let env = ServerEnvironment(id: id, name: "Local", host: "localhost", port: 50051)
        mockRepository.savedEnvironments = [env]

        sut.execute(id: id)

        XCTAssertTrue(mockRepository.savedEnvironments.isEmpty)
        XCTAssertEqual(mockRepository.deletedIds, [id])
    }

    func test_execute_whenIdNotFound_isNoOp() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockRepository.savedEnvironments = [env]

        sut.execute(id: UUID())

        XCTAssertEqual(mockRepository.savedEnvironments.count, 1)
    }

    func test_execute_delegatesToRepository() {
        let id = UUID()

        sut.execute(id: id)

        XCTAssertEqual(mockRepository.deletedIds, [id])
    }
}
