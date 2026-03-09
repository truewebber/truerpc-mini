import Foundation
@testable import TrueRPCMini

class MockDeleteEnvironmentUseCase: DeleteEnvironmentUseCaseProtocol {
    var deletedIds: [UUID] = []

    func execute(id: UUID) {
        deletedIds.append(id)
    }
}
