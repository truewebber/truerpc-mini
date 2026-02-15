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
        
        let savedPaths = protoPathsPersistence.getProtoPaths()
        print("DEBUG: Retrieved \(savedPaths.count) saved paths")
        guard !savedPaths.isEmpty else {
            isLoading = false
            return
        }
        
        let importPaths = importPathsRepository.getImportPaths()
        let loadedProtos = await loadSavedProtosUseCase.execute(urls: savedPaths, importPaths: importPaths)
        print("DEBUG: Loaded \(loadedProtos.count) proto files")
        protoFiles = loadedProtos
        
        isLoading = false
    }
    
    /// Imports a proto file from the given URL
    /// Uses configured import paths for dependency resolution
    /// Saves the path to persistent storage after successful import
    public func importProtoFile(url: URL) async {
        print("DEBUG: importProtoFile() called with: \(url.path)")
        isLoading = true
        error = nil
        
        do {
            let importPaths = importPathsRepository.getImportPaths()
            let protoFile = try await importProtoFileUseCase.execute(url: url, importPaths: importPaths)
            protoFiles.append(protoFile)
            print("DEBUG: Successfully imported proto file: \(protoFile.name)")
            
            // Save paths after successful import
            saveProtoPaths()
        } catch {
            self.error = error.localizedDescription
            print("DEBUG: Import failed: \(error.localizedDescription)")
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
