import Foundation

/// Loads proto files from saved paths.
///
/// A path that fails to parse is returned as a failure and does not stop the others from loading.
public final class LoadSavedProtosUseCase: LoadSavedProtosUseCaseProtocol {
    private let importProtoFileUseCase: ImportProtoFileUseCaseProtocol
    private let logger: AppLogger

    public init(importProtoFileUseCase: ImportProtoFileUseCaseProtocol, logger: AppLogger) {
        self.importProtoFileUseCase = importProtoFileUseCase
        self.logger = logger
    }

    /// Loads every saved path. Failures are reported with the paths that parsed.
    public func execute(urls: [URL], importPaths: [String]) async -> SavedProtosLoadResult {
        var loaded: [ProtoFile] = []
        var failures: [FailedProtoImport] = []

        for url in urls {
            do {
                let proto = try await importProtoFileUseCase.execute(url: url, importPaths: importPaths)
                loaded.append(proto)
            } catch {
                logger.error("Proto loading failed", metadata: [
                    "file": url.path,
                    "error": error.localizedDescription,
                ])
                failures.append(FailedProtoImport(path: url, message: error.localizedDescription))
            }
        }

        return SavedProtosLoadResult(loaded: loaded, failures: failures)
    }
}
