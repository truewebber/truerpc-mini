import Foundation
@testable import TrueRPCMini

@MainActor
final class MockExportResponseUseCase: ExportResponseUseCaseProtocol {
    var executeCalled = false
    var capturedResponse: GrpcResponse?
    var capturedDestination: URL?
    var capturedIncludeMetadata: Bool = false

    init() {}

    func execute(
        response: GrpcResponse,
        destination: URL,
        includeMetadata: Bool = false)
        throws
    {
        executeCalled = true
        capturedResponse = response
        capturedDestination = destination
        capturedIncludeMetadata = includeMetadata
    }

    func generateDefaultFilename() -> String {
        "mock_response.json"
    }
}
