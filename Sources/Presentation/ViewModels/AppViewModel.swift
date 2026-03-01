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
    private let executeRequestUseCase: ExecuteUnaryRequestUseCaseProtocol
    private let exportResponseUseCase: ExportResponseUseCase
    private let logger: AppLogger

    // MARK: - Initialization

    public init(
        createEditorTabUseCase: CreateEditorTabUseCase,
        generateMockDataUseCase: GenerateMockDataUseCase,
        executeRequestUseCase: ExecuteUnaryRequestUseCaseProtocol,
        exportResponseUseCase: ExportResponseUseCase,
        logger: AppLogger
    ) {
        self.createEditorTabUseCase = createEditorTabUseCase
        self.generateMockDataUseCase = generateMockDataUseCase
        self.executeRequestUseCase = executeRequestUseCase
        self.exportResponseUseCase = exportResponseUseCase
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Opens an editor tab for the selected method
    public func openMethod(method: Method, service: Service, protoFile: ProtoFile) {
        let editorTab = createEditorTabUseCase.execute(method: method, service: service, protoFile: protoFile)
        let tabViewModel = EditorTabViewModel(
            editorTab: editorTab,
            generateMockDataUseCase: generateMockDataUseCase,
            executeRequestUseCase: executeRequestUseCase,
            exportResponseUseCase: exportResponseUseCase,
            logger: logger
        )
        selectedEditorTab = tabViewModel
    }
}
