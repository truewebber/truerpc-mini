import XCTest
@testable import TrueRPCMini

final class SelectEnvironmentUseCaseTests: XCTestCase {
    var sut: SelectEnvironmentUseCase!
    var mockRepository: MockEnvironmentRepository!

    override func setUp() {
        super.setUp()
        mockRepository = MockEnvironmentRepository()
        sut = SelectEnvironmentUseCase(repository: mockRepository)
    }

    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }

    func test_execute_withEnvironment_persistsId() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)

        sut.execute(env)

        XCTAssertEqual(mockRepository.selectedId, env.id)
    }

    func test_execute_withNil_clearsId() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        mockRepository.selectedId = env.id

        sut.execute(nil)

        XCTAssertNil(mockRepository.selectedId)
    }
}
