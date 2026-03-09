import Foundation
@testable import TrueRPCMini

class MockGetSelectedEnvironmentUseCase: GetSelectedEnvironmentUseCaseProtocol {
    var stubbedResult: ServerEnvironment?

    func execute() -> ServerEnvironment? {
        stubbedResult
    }
}
