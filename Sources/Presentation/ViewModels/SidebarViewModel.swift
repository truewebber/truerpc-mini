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
    
    private let importProtoFileUseCase: MockImportProtoFileUseCase
    
    // MARK: - Initialization
    
    public init(importProtoFileUseCase: MockImportProtoFileUseCase) {
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

// MARK: - Temporary Mock Type (will be replaced with protocol)

public class MockImportProtoFileUseCase {
    public func execute(url: URL) async throws -> ProtoFile {
        fatalError("Must be implemented by mock or real use case")
    }
}
