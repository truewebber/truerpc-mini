import Foundation
@testable import TrueRPCMini

class MockGetSelectedEnvironmentUseCase: GetSelectedEnvironmentUseCaseProtocol {
    var stubbedResult: ServerEnvironment?

    /// When non-empty, returns values in order per execute() call; then falls back to stubbedResult.
    /// Use when simulating persistence (e.g. first call returns env, second returns nil after "clear").
    var returnValues: [ServerEnvironment?] = []

    func execute() -> ServerEnvironment? {
        if !returnValues.isEmpty {
            return returnValues.removeFirst()
        }
        return stubbedResult
    }
}
