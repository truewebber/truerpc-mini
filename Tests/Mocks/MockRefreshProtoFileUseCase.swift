import Foundation
@testable import TrueRPCMini

/// Mock implementation of RefreshProtoFileUseCaseProtocol for testing
@MainActor
public final class MockRefreshProtoFileUseCase: RefreshProtoFileUseCaseProtocol {
    public var callCount = 0
    public var lastProtoFile: ProtoFile?
    public var lastImportPaths: [String]?
    public var mockResultsByPath: [URL: Result<ProtoFile, Error>] = [:]

    public init() {}

    public func execute(protoFile: ProtoFile, importPaths: [String]) throws -> ProtoFile {
        callCount += 1
        lastProtoFile = protoFile
        lastImportPaths = importPaths

        guard let result = mockResultsByPath[protoFile.path] else {
            throw NSError(
                domain: "test",
                code: 999,
                userInfo: [NSLocalizedDescriptionKey: "No mock result configured for path: \(protoFile.path)"])
        }

        switch result {
        case let .success(proto):
            return proto
        case let .failure(error):
            throw error
        }
    }
}
