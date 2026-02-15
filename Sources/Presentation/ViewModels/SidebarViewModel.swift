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
    
    // MARK: - Initialization
    
    public init(importProtoFileUseCase: ImportProtoFileUseCaseProtocol) {
        self.importProtoFileUseCase = importProtoFileUseCase
    }
    
    // MARK: - Public Methods
    
    /// Imports a proto file from the given URL
    public func importProtoFile(url: URL) async {
        isLoading = true
        error = nil
        
        do {
            let protoFile = try await importProtoFileUseCase.execute(url: url)
            protoFiles.append(protoFile)
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}
