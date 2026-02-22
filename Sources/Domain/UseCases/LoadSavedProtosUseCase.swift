import Foundation

/// Use case for loading proto files from saved paths
/// Attempts to load each proto file, skips files that fail to load
public class LoadSavedProtosUseCase {
    private let importProtoFileUseCase: ImportProtoFileUseCaseProtocol
    
    public init(importProtoFileUseCase: ImportProtoFileUseCaseProtocol) {
        self.importProtoFileUseCase = importProtoFileUseCase
    }
    
    /// Executes the loading of saved proto files
    /// - Parameters:
    ///   - urls: Array of file URLs to load
    ///   - importPaths: Array of directory paths for resolving proto dependencies
    /// - Returns: Array of successfully loaded ProtoFile entities (failures are silently skipped)
    public func execute(urls: [URL], importPaths: [String]) async -> [ProtoFile] {
        var loadedProtos: [ProtoFile] = []
        
        for url in urls {
            do {
                let proto = try await importProtoFileUseCase.execute(url: url, importPaths: importPaths)
                loadedProtos.append(proto)
            } catch {
                print("DEBUG: LoadSavedProtos failed for \(url.path): \(error.localizedDescription)")
                continue
            }
        }
        
        return loadedProtos
    }
}
