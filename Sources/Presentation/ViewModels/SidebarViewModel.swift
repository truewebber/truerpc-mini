import Foundation
import SwiftUI

/// ViewModel for the Sidebar managing proto file imports and display
@MainActor
public final class SidebarViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var protoFiles: [ProtoFile] = [] {
        didSet { updateContractColorSlots() }
    }

    @Published public var error: String?
    @Published public var isLoading: Bool = false
    /// Proto files that were added but could not be parsed. Removing one drops it; retrying loads it.
    @Published public internal(set) var failedImports: [FailedProtoImport] = []
    /// Parse error for a contract that is still loaded, keyed by file path.
    @Published public internal(set) var contractErrors: [URL: String] = [:]
    @Published public private(set) var importPathsCount: Int = 0
    /// Color slot of every loaded contract, keyed by proto file path.
    @Published public private(set) var contractColorSlots: [URL: Int] = [:]

    // MARK: - Dependencies

    private let importProtoFileUseCase: ImportProtoFileUseCaseProtocol
    private let refreshProtoFileUseCase: RefreshProtoFileUseCaseProtocol
    private let watcher: ProtoFileWatcherProtocol
    private let importPathsRepository: ImportPathsRepositoryProtocol
    private let protoPathsPersistence: ProtoPathsPersistenceProtocol
    private let loadSavedProtosUseCase: LoadSavedProtosUseCaseProtocol
    private let assignContractColorSlotsUseCase: AssignContractColorSlotsUseCaseProtocol
    private let logger: AppLogger
    private let telemetry: TelemetryServiceProtocol

    private nonisolated(unsafe) var watcherTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(
        importProtoFileUseCase: ImportProtoFileUseCaseProtocol,
        refreshProtoFileUseCase: RefreshProtoFileUseCaseProtocol,
        watcher: ProtoFileWatcherProtocol,
        importPathsRepository: ImportPathsRepositoryProtocol,
        protoPathsPersistence: ProtoPathsPersistenceProtocol,
        loadSavedProtosUseCase: LoadSavedProtosUseCaseProtocol,
        assignContractColorSlotsUseCase: AssignContractColorSlotsUseCaseProtocol,
        logger: AppLogger,
        telemetry: TelemetryServiceProtocol)
    {
        self.importProtoFileUseCase = importProtoFileUseCase
        self.refreshProtoFileUseCase = refreshProtoFileUseCase
        self.watcher = watcher
        self.importPathsRepository = importPathsRepository
        self.protoPathsPersistence = protoPathsPersistence
        self.loadSavedProtosUseCase = loadSavedProtosUseCase
        self.assignContractColorSlotsUseCase = assignContractColorSlotsUseCase
        self.logger = logger
        self.telemetry = telemetry
        self.importPathsCount = importPathsRepository.getImportPaths().count
        startWatcherConsumerTask()
    }

    deinit {
        watcherTask?.cancel()
    }

    public func refreshImportPathsCount() {
        importPathsCount = importPathsRepository.getImportPaths().count
    }

    // MARK: - Private Watcher Setup

    private func startWatcherConsumerTask() {
        watcherTask = Task { [weak self, watcher] in
            for await protoFile in watcher.changes {
                guard let self else { break }

                await refreshProtoFile(protoFile)
            }
        }
    }

    // MARK: - Public Methods

    /// Loads saved proto files from persistent storage
    /// Called on app startup to restore previous session
    public func loadSavedProtos() async {
        isLoading = true
        error = nil

        await loadWellKnownTypes()

        let savedPaths = protoPathsPersistence.getProtoPaths()
        guard !savedPaths.isEmpty else {
            isLoading = false
            return
        }

        let importPaths = getImportPathsWithWellKnownTypes()
        let loadedProtos = await loadSavedProtosUseCase.execute(urls: savedPaths, importPaths: importPaths)
        failedImports = loadedProtos.failures
        for proto in loadedProtos.loaded {
            addOrReplaceProtoFile(proto)
            watcher.startWatching(proto)
        }
        logger.info("Saved proto files loaded", metadata: [
            "count": "\(loadedProtos.loaded.count)",
            "files": loadedProtos.loaded.map(\.name).joined(separator: ","),
        ])

        isLoading = false
    }

    /// Loads Google well-known types (Empty, Timestamp, etc.)
    /// These are loaded silently and not shown in sidebar
    private func loadWellKnownTypes() async {
        guard let resourcesPath = Bundle.main.resourcePath else {
            return
        }

        let wellKnownTypesPath = URL(fileURLWithPath: resourcesPath)
            .appendingPathComponent("Resources")
            .appendingPathComponent("google")
            .appendingPathComponent("protobuf")

        // Check if well-known types directory exists
        guard FileManager.default.fileExists(atPath: wellKnownTypesPath.path) else {
            return
        }

        // Load essential well-known types
        let wellKnownFiles = ["empty.proto", "timestamp.proto", "duration.proto", "wrappers.proto"]

        for filename in wellKnownFiles {
            let fileURL = wellKnownTypesPath.appendingPathComponent(filename)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    _ = try await importProtoFileUseCase.execute(url: fileURL, importPaths: [])
                } catch {
                    logger.warning("Well-known type loading failed", metadata: [
                        "file": filename,
                        "error": error.localizedDescription,
                    ])
                }
            }
        }
    }

    /// Get import paths including well-known types location
    private func getImportPathsWithWellKnownTypes() -> [String] {
        var paths = importPathsRepository.getImportPaths()

        // The Resources folder is bundled as a folder reference, so it lands one level
        // deeper: Contents/Resources/Resources/google/protobuf/*.proto
        // SwiftProtoParser resolves "google/protobuf/timestamp.proto" relative to this path.
        if let resourcesPath = Bundle.main.resourcePath {
            let wellKnownImportPath = URL(fileURLWithPath: resourcesPath)
                .appendingPathComponent("Resources").path
            paths.append(wellKnownImportPath)
        }

        return paths
    }

    /// Imports a proto file from the given URL.
    ///
    /// A file that fails to parse is kept as a failed import, beside the contracts that already load,
    /// and its path is saved so it can be removed or retried later.
    public func importProtoFile(url: URL) async {
        isLoading = true
        error = nil

        do {
            let importPaths = getImportPathsWithWellKnownTypes()
            let protoFile = try await importProtoFileUseCase.execute(url: url, importPaths: importPaths)
            contractErrors[url] = nil
            failedImports.removeAll { $0.path == url }
            addOrReplaceProtoFile(protoFile)
            watcher.startWatching(protoFile)
            logger.info("Proto file imported", metadata: [
                "name": protoFile.name,
                "path": url.path,
                "total": "\(protoFiles.count)",
            ])
            await telemetry.track(.protoAdded(source: "file"))

            saveProtoPaths()
        } catch {
            logger.error("Proto file import failed", metadata: [
                "path": url.path,
                "error": error.localizedDescription,
            ])
            await telemetry.track(.protoLoadFailed(source: "file"))
            recordImportFailure(url, message: error.localizedDescription)
            saveProtoPaths()
        }

        isLoading = false
    }

    /// Removes a proto file from the list, persists the updated set, and fires telemetry
    public func removeProtoFile(_ protoFile: ProtoFile) async {
        watcher.stopWatching(protoFile)
        protoFiles.removeAll { $0.id == protoFile.id }
        contractErrors[protoFile.path] = nil
        saveProtoPaths()
        await telemetry.track(.protoRemoved())
    }

    /// Drops a proto file that never parsed and forgets its saved path.
    public func removeFailedImport(_ failure: FailedProtoImport) async {
        failedImports.removeAll { $0.path == failure.path }
        saveProtoPaths()
        await telemetry.track(.protoRemoved())
    }

    /// Tries every failed import again, then refreshes loaded contracts that are showing an error.
    public func retryFailedContracts() async {
        let paths = failedImports.map(\.path)
        for path in paths {
            await importProtoFile(url: path)
        }

        let stale = protoFiles.filter { contractErrors[$0.path] != nil }
        for protoFile in stale {
            await refreshProtoFile(protoFile)
        }
    }

    /// Re-parses an already-loaded proto file and replaces the stale entry in `protoFiles`.
    /// A failure keeps the previous contract and records the message on that row.
    public func refreshProtoFile(_ protoFile: ProtoFile) async {
        error = nil

        let importPaths = getImportPathsWithWellKnownTypes()

        do {
            let updated = try await refreshProtoFileUseCase.execute(
                protoFile: protoFile,
                importPaths: importPaths)
            contractErrors[protoFile.path] = nil
            addOrReplaceProtoFile(updated)
            await telemetry.track(.protoRefreshed())
        } catch {
            logger.error("Proto file refresh failed", metadata: [
                "name": protoFile.name,
                "error": error.localizedDescription,
            ])
            contractErrors[protoFile.path] = error.localizedDescription
        }
    }

    // MARK: - Private Methods

    private func saveProtoPaths() {
        let paths = protoFiles.map(\.path) + failedImports.map(\.path)
        protoPathsPersistence.saveProtoPaths(paths)
    }

    /// A contract that already loaded keeps its services and shows the new error on its row.
    private func recordImportFailure(_ url: URL, message: String) {
        if protoFiles.contains(where: { $0.path == url }) {
            contractErrors[url] = message
            failedImports.removeAll { $0.path == url }
            return
        }

        let failure = FailedProtoImport(path: url, message: message)
        if let index = failedImports.firstIndex(where: { $0.path == url }) {
            failedImports[index] = failure
        } else {
            failedImports.append(failure)
        }
    }

    /// Logs the picker error and exposes it to the UI.
    public func handlePickerError(_ error: Error) {
        logger.error("File import picker failed", metadata: [
            "error": error.localizedDescription,
        ])
        self.error = error.localizedDescription
    }

    private func updateContractColorSlots() {
        contractColorSlots = assignContractColorSlotsUseCase.execute(
            protoFilePaths: protoFiles.map(\.path),
            currentSlots: contractColorSlots)
    }

    private func addOrReplaceProtoFile(_ protoFile: ProtoFile) {
        if let index = protoFiles.firstIndex(where: { $0.path == protoFile.path }) {
            protoFiles[index] = protoFile
        } else {
            protoFiles.append(protoFile)
        }
    }
}
