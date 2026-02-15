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
    
    // MARK: - Initialization
    
    public init(
        importProtoFileUseCase: ImportProtoFileUseCaseProtocol,
        importPathsRepository: ImportPathsRepositoryProtocol
    ) {
        self.importProtoFileUseCase = importProtoFileUseCase
        self.importPathsRepository = importPathsRepository
    }
    
    // MARK: - Public Methods
    
    /// Imports a proto file from the given URL
    /// Uses configured import paths for dependency resolution
    public func importProtoFile(url: URL) async {
        isLoading = true
        error = nil
        
        do {
            let importPaths = importPathsRepository.getImportPaths()
            let protoFile = try await importProtoFileUseCase.execute(url: url, importPaths: importPaths)
            protoFiles.append(protoFile)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}
