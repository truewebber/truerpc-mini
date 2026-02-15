import Foundation
import SwiftUI

/// Main app coordinator managing navigation between sidebar and editor
@MainActor
public final class AppViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published public var selectedEditorTab: EditorTabViewModel?
    
    // MARK: - Dependencies
    
    private let createEditorTabUseCase: CreateEditorTabUseCase
    private let generateMockDataUseCase: GenerateMockDataUseCase
    
    // MARK: - Initialization
    
    public init(
        createEditorTabUseCase: CreateEditorTabUseCase,
        generateMockDataUseCase: GenerateMockDataUseCase
    ) {
        self.createEditorTabUseCase = createEditorTabUseCase
        self.generateMockDataUseCase = generateMockDataUseCase
    }
    
    // MARK: - Public Methods
    
    /// Opens an editor tab for the selected method
    public func openMethod(method: Method, service: Service, protoFile: ProtoFile) {
        let editorTab = createEditorTabUseCase.execute(method: method, service: service, protoFile: protoFile)
        let tabViewModel = EditorTabViewModel(
            editorTab: editorTab,
            generateMockDataUseCase: generateMockDataUseCase
        )
        selectedEditorTab = tabViewModel
    }
}
