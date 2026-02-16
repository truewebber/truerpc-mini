import Foundation
import SwiftUI

/// ViewModel for the Sidebar managing proto file imports and display
@MainActor
public final class SidebarViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var protoFiles: [ProtoFile] = []
    @Published public var error: String?
    @Published public var isLoading: Bool = false
    
    // MARK: - Dependencies
    
    private let importProtoFileUseCase: ImportProtoFileUseCaseProtocol
    private let importPathsRepository: ImportPathsRepositoryProtocol
    private let protoPathsPersistence: ProtoPathsPersistenceProtocol
    private let loadSavedProtosUseCase: LoadSavedProtosUseCase
    
    // MARK: - Initialization
    
    public init(
        importProtoFileUseCase: ImportProtoFileUseCaseProtocol,
        importPathsRepository: ImportPathsRepositoryProtocol,
        protoPathsPersistence: ProtoPathsPersistenceProtocol,
        loadSavedProtosUseCase: LoadSavedProtosUseCase
    ) {
        self.importProtoFileUseCase = importProtoFileUseCase
        self.importPathsRepository = importPathsRepository
        self.protoPathsPersistence = protoPathsPersistence
        self.loadSavedProtosUseCase = loadSavedProtosUseCase
    }
    
    // MARK: - Public Methods
    
    /// Loads saved proto files from persistent storage
    /// Called on app startup to restore previous session
    public func loadSavedProtos() async {
        print("DEBUG: loadSavedProtos() called")
        isLoading = true
        error = nil
        
        // Load well-known types first
        await loadWellKnownTypes()
        
        let savedPaths = protoPathsPersistence.getProtoPaths()
        guard !savedPaths.isEmpty else {
            isLoading = false
            return
        }
        
        let importPaths = getImportPathsWithWellKnownTypes()
        let loadedProtos = await loadSavedProtosUseCase.execute(urls: savedPaths, importPaths: importPaths)
        protoFiles.append(contentsOf: loadedProtos)
        
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
                    // Import silently (no import paths needed for well-known types)
                    _ = try await importProtoFileUseCase.execute(url: fileURL, importPaths: [])
                } catch {
                    // Silently continue if a well-known type fails to load
                }
            }
        }
    }
    
    /// Get import paths including well-known types location
    private func getImportPathsWithWellKnownTypes() -> [String] {
        var paths = importPathsRepository.getImportPaths()
        
        // Add Resources path for well-known types
        if let resourcesPath = Bundle.main.resourcePath {
            paths.append(resourcesPath)
        }
        
        return paths
    }
    
    /// Imports a proto file from the given URL
    /// Uses configured import paths for dependency resolution
    /// Saves the path to persistent storage after successful import
    public func importProtoFile(url: URL) async {
        isLoading = true
        error = nil
        
        do {
            let importPaths = getImportPathsWithWellKnownTypes()
            let protoFile = try await importProtoFileUseCase.execute(url: url, importPaths: importPaths)
            protoFiles.append(protoFile)
            
            // Save paths after successful import
            saveProtoPaths()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func saveProtoPaths() {
        let paths = protoFiles.map { $0.path }
        print("DEBUG: saveProtoPaths() called with \(paths.count) paths")
        protoPathsPersistence.saveProtoPaths(paths)
    }
}
