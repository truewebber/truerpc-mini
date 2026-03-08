import Foundation

/// Use case for loading proto files from saved paths
/// Attempts to load each proto file, skips files that fail to load
public class LoadSavedProtosUseCase {
    private let importProtoFileUseCase: ImportProtoFileUseCaseProtocol
    private let logger: AppLogger

    public init(importProtoFileUseCase: ImportProtoFileUseCaseProtocol, logger: AppLogger) {
        self.importProtoFileUseCase = importProtoFileUseCase
        self.logger = logger
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
                logger.error("Proto loading failed", metadata: [
                    "file": url.path,
                    "error": error.localizedDescription,
                ])
                continue
            }
        }

        return loadedProtos
    }
}
