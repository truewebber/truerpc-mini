import Foundation
@testable import TrueRPCMini

@MainActor
final class MockGenerateMockDataUseCase: GenerateMockDataUseCaseProtocol {
    var mockJSON: String = "{}"
    var executeCallCount = 0
    var shouldThrow = false
    var capturedMethod: TrueRPCMini.Method?
    var capturedProtoFile: TrueRPCMini.ProtoFile?

    init() {}

    func execute(method: TrueRPCMini.Method, protoFile: TrueRPCMini.ProtoFile) throws -> String {
        executeCallCount += 1
        capturedMethod = method
        capturedProtoFile = protoFile
        if shouldThrow {
            throw NSError(domain: "mock", code: 0, userInfo: [NSLocalizedDescriptionKey: "mock generation failed"])
        }
        return mockJSON
    }
}
