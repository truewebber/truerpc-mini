import Foundation
import SwiftUI

/// ViewModel for managing request editor tab state
@MainActor
public final class EditorTabViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var requestJson: String = ""
    @Published public var url: String = ""
    @Published public var isLoading: Bool = false
    
    // MARK: - Properties
    
    public let editorTab: EditorTab
    
    // MARK: - Dependencies
    
    private let generateMockDataUseCase: GenerateMockDataUseCase
    
    // MARK: - Initialization
    
    public init(
        editorTab: EditorTab,
        generateMockDataUseCase: GenerateMockDataUseCase
    ) {
        self.editorTab = editorTab
        self.generateMockDataUseCase = generateMockDataUseCase
    }
    
    // MARK: - Public Methods
    
    /// Loads mock data for the method's input type
    public func loadMockData() async {
        isLoading = true
        
        do {
            let mockJson = try await generateMockDataUseCase.execute(method: editorTab.method)
            requestJson = mockJson
        } catch {
            // Silently fail for MVP - just leave empty JSON
            print("DEBUG: Failed to generate mock data: \(error)")
        }
        
        isLoading = false
    }
    
    /// Updates the request JSON
    public func updateJson(_ newJson: String) {
        requestJson = newJson
    }
    
    /// Updates the server URL
    public func updateUrl(_ newUrl: String) {
        url = newUrl
    }
}
