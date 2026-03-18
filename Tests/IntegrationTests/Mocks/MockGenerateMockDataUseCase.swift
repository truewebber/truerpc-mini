import Foundation
@testable import TrueRPCMini

@MainActor
final class MockGenerateMockDataUseCase: GenerateMockDataUseCaseProtocol {
    var mockJSON: String = "{}"
    var executeCallCount = 0
    var shouldThrow = false

    init() {}

    func execute(method _: TrueRPCMini.Method) throws -> String {
        executeCallCount += 1
        if shouldThrow {
            throw NSError(domain: "mock", code: 0, userInfo: [NSLocalizedDescriptionKey: "mock generation failed"])
        }
        return mockJSON
    }
}
