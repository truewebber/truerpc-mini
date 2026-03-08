import Foundation
@testable import TrueRPCMini

/// Mock implementation of ImportProtoFileUseCaseProtocol for testing
public class MockImportProtoFileUseCase: ImportProtoFileUseCaseProtocol {
    public var callCount = 0
    public var lastURL: URL?
    public var lastImportPaths: [String]?
    public var mockResultsByURL: [URL: Result<ProtoFile, Error>] = [:]

    public init() {}

    public func execute(url: URL) throws -> ProtoFile {
        callCount += 1
        lastURL = url
        lastImportPaths = []

        guard let result = mockResultsByURL[url] else {
            throw NSError(
                domain: "test",
                code: 999,
                userInfo: [NSLocalizedDescriptionKey: "No mock result configured for URL: \(url)"])
        }

        switch result {
        case let .success(proto):
            return proto
        case let .failure(error):
            throw error
        }
    }

    public func execute(url: URL, importPaths: [String]) throws -> ProtoFile {
        callCount += 1
        lastURL = url
        lastImportPaths = importPaths

        guard let result = mockResultsByURL[url] else {
            throw NSError(
                domain: "test",
                code: 999,
                userInfo: [NSLocalizedDescriptionKey: "No mock result configured for URL: \(url)"])
        }

        switch result {
        case let .success(proto):
            return proto
        case let .failure(error):
            throw error
        }
    }
}
