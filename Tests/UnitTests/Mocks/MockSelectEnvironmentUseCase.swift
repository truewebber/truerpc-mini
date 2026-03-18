import Foundation
@testable import TrueRPCMini

class MockSelectEnvironmentUseCase: SelectEnvironmentUseCaseProtocol {
    var executeCallCount = 0
    var lastExecuted: ServerEnvironment??

    func execute(_ environment: ServerEnvironment?) {
        executeCallCount += 1
        lastExecuted = environment
    }
}
