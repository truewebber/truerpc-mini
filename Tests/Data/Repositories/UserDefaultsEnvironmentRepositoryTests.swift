import XCTest
@testable import TrueRPCMini

final class UserDefaultsEnvironmentRepositoryTests: XCTestCase {
    var sut: UserDefaultsEnvironmentRepository!
    var userDefaults: UserDefaults!
    let testSuite = "test-environment-repository"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: testSuite)!
        userDefaults.removePersistentDomain(forName: testSuite)
        sut = UserDefaultsEnvironmentRepository(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: testSuite)
        sut = nil
        userDefaults = nil
        super.tearDown()
    }

    // MARK: - getAll

    func test_getAll_whenEmpty_returnsEmptyArray() {
        let result = sut.getAll()

        XCTAssertTrue(result.isEmpty)
    }

    func test_getAll_afterSave_returnsEnvironment() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)

        sut.save(env)
        let result = sut.getAll()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, env.id)
        XCTAssertEqual(result[0].name, env.name)
        XCTAssertEqual(result[0].host, env.host)
        XCTAssertEqual(result[0].port, env.port)
    }

    func test_getAll_afterSaveMultiple_returnsAllInOrder() {
        let env1 = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        let env2 = ServerEnvironment(name: "Staging", host: "staging.example.com", port: 443)
        let env3 = ServerEnvironment(name: "Prod", host: "prod.example.com", port: 443)

        sut.save(env1)
        sut.save(env2)
        sut.save(env3)

        let result = sut.getAll()
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].id, env1.id)
        XCTAssertEqual(result[1].id, env2.id)
        XCTAssertEqual(result[2].id, env3.id)
    }

    // MARK: - save (upsert)

    func test_save_updatesExistingEnvironment() {
        let id = UUID()
        let original = ServerEnvironment(id: id, name: "Local", host: "localhost", port: 50051)
        sut.save(original)

        let updated = ServerEnvironment(id: id, name: "Local Dev", host: "127.0.0.1", port: 8080)
        sut.save(updated)

        let result = sut.getAll()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "Local Dev")
        XCTAssertEqual(result[0].host, "127.0.0.1")
        XCTAssertEqual(result[0].port, 8080)
    }

    // MARK: - delete

    func test_delete_removesEnvironmentById() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        sut.save(env)

        sut.delete(id: env.id)

        XCTAssertTrue(sut.getAll().isEmpty)
    }

    func test_delete_whenIdNotFound_isNoOp() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        sut.save(env)

        sut.delete(id: UUID())

        XCTAssertEqual(sut.getAll().count, 1)
    }

    func test_delete_removesOnlyTargetEnvironment() {
        let env1 = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        let env2 = ServerEnvironment(name: "Staging", host: "staging.example.com", port: 443)
        sut.save(env1)
        sut.save(env2)

        sut.delete(id: env1.id)

        let result = sut.getAll()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, env2.id)
    }

    // MARK: - selectedId

    func test_getSelectedId_whenNotSet_returnsNil() {
        XCTAssertNil(sut.getSelectedId())
    }

    func test_setSelectedId_persistsValue() {
        let id = UUID()

        sut.setSelectedId(id)

        XCTAssertEqual(sut.getSelectedId(), id)
    }

    func test_setSelectedId_nil_clearsValue() {
        let id = UUID()
        sut.setSelectedId(id)

        sut.setSelectedId(nil)

        XCTAssertNil(sut.getSelectedId())
    }

    func test_setSelectedId_persistsAcrossInstances() {
        let id = UUID()
        sut.setSelectedId(id)

        let newSut = UserDefaultsEnvironmentRepository(userDefaults: userDefaults)

        XCTAssertEqual(newSut.getSelectedId(), id)
    }

    // MARK: - Persistence

    func test_persistsAcrossInstances() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)
        sut.save(env)

        let newSut = UserDefaultsEnvironmentRepository(userDefaults: userDefaults)
        let result = newSut.getAll()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, env.id)
    }
}
