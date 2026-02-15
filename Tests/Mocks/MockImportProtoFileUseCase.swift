import Foundation
@testable import TrueRPCMini

/// Mock implementation of ImportProtoFileUseCaseProtocol for testing
public class MockImportProtoFileUseCase: ImportProtoFileUseCaseProtocol {
    public var callCount = 0
    public var lastURL: URL?
    public var lastImportPaths: [String]?
    public var mockResultsByURL: [URL: Result<ProtoFile, Error>] = [:]
    
    public init() {}
    
    public func execute(url: URL) async throws -> ProtoFile {
        callCount += 1
        lastURL = url
        lastImportPaths = []
        
        guard let result = mockResultsByURL[url] else {
            throw NSError(domain: "test", code: 999, userInfo: [NSLocalizedDescriptionKey: "No mock result configured for URL: \(url)"])
        }
        
        switch result {
        case .success(let proto):
            return proto
        case .failure(let error):
            throw error
        }
    }
    
    public func execute(url: URL, importPaths: [String]) async throws -> ProtoFile {
        callCount += 1
        lastURL = url
        lastImportPaths = importPaths
        
        guard let result = mockResultsByURL[url] else {
            throw NSError(domain: "test", code: 999, userInfo: [NSLocalizedDescriptionKey: "No mock result configured for URL: \(url)"])
        }
        
        switch result {
        case .success(let proto):
            return proto
        case .failure(let error):
            throw error
        }
    }
}
