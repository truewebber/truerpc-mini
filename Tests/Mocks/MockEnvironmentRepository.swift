import Foundation
@testable import TrueRPCMini

class MockEnvironmentRepository: EnvironmentRepositoryProtocol {
    var savedEnvironments: [ServerEnvironment] = []
    var deletedIds: [UUID] = []
    var stubbedGetAll: [ServerEnvironment] = []
    var selectedId: UUID?

    func save(_ environment: ServerEnvironment) {
        if let index = savedEnvironments.firstIndex(where: { $0.id == environment.id }) {
            savedEnvironments[index] = environment
        } else {
            savedEnvironments.append(environment)
        }
    }

    func delete(id: UUID) {
        deletedIds.append(id)
        savedEnvironments.removeAll { $0.id == id }
    }

    func getAll() -> [ServerEnvironment] {
        stubbedGetAll.isEmpty ? savedEnvironments : stubbedGetAll
    }

    func getSelectedId() -> UUID? {
        selectedId
    }

    func setSelectedId(_ id: UUID?) {
        selectedId = id
    }
}
