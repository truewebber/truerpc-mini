import Foundation
@testable import TrueRPCMini

class MockLoadEnvironmentsUseCase: LoadEnvironmentsUseCaseProtocol {
    var executeCallCount = 0
    var stubbedResult: [ServerEnvironment] = []

    func execute() -> [ServerEnvironment] {
        executeCallCount += 1
        return stubbedResult
    }
}
