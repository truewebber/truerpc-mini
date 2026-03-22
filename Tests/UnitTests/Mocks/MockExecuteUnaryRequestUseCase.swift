import Foundation
@testable import TrueRPCMini

@MainActor
final class MockExecuteUnaryRequestUseCase: ExecuteUnaryRequestUseCaseProtocol {
    var executeCalled = false
    var capturedRequest: RequestDraft?
    var capturedMethod: TrueRPCMini.Method?
    var capturedProtoFile: ProtoFile?
    var stubbedResponse: GrpcResponse?
    var shouldThrowError: GrpcClientError?
    var shouldThrow: Bool = false
    var errorToThrow: GrpcClientError?
    var protoErrorToThrow: ProtoRepositoryError?
    var arbitraryErrorToThrow: Error?

    func execute(request: RequestDraft, method: TrueRPCMini.Method, protoFile: ProtoFile) throws -> GrpcResponse {
        executeCalled = true
        capturedRequest = request
        capturedMethod = method
        capturedProtoFile = protoFile

        if let error = protoErrorToThrow {
            throw error
        }

        if let error = arbitraryErrorToThrow {
            throw error
        }

        if shouldThrow, let error = errorToThrow {
            throw error
        }

        if let error = shouldThrowError {
            throw error
        }

        guard let response = stubbedResponse else {
            throw GrpcClientError.unknown("No stubbed response")
        }

        return response
    }
}
