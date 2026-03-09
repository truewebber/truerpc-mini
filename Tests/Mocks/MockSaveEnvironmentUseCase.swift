import Foundation
@testable import TrueRPCMini

class MockSaveEnvironmentUseCase: SaveEnvironmentUseCaseProtocol {
    var savedEnvironments: [ServerEnvironment] = []

    func execute(_ environment: ServerEnvironment) {
        savedEnvironments.append(environment)
    }
}
