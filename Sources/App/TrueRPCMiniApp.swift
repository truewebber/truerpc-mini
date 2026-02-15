import SwiftUI

@main
struct TrueRPCMiniApp: App {
    // MARK: - Properties
    
    /// Dependency Injection container
    private let di: AppDI
    
    /// Sidebar ViewModel (created once and reused)
    @StateObject private var sidebarViewModel: SidebarViewModel
    
    /// App coordinator ViewModel
    @StateObject private var appViewModel: AppViewModel
    
    // MARK: - Initialization
    
    init() {
        // Initialize DI container
        let di = AppDI()
        self.di = di
        
        // Register Data Layer dependencies
        di.register(ProtoRepositoryProtocol.self) {
            FileSystemProtoRepository()
        }
        
        di.register(ImportPathsRepositoryProtocol.self) {
            UserDefaultsImportPathsRepository()
        }
        
        di.register(ProtoPathsPersistenceProtocol.self) {
            UserDefaultsProtoPathsRepository()
        }
        
        di.register(MockDataGeneratorProtocol.self) {
            MockDataGenerator()
        }
        
        di.register(GrpcClientProtocol.self) {
            GrpcSwiftDynamicClient(
                protoRepository: di.resolve(ProtoRepositoryProtocol.self)!
            )
        }
        
        // Register Domain Layer dependencies
        di.register(ImportProtoFileUseCaseProtocol.self) {
            ImportProtoFileUseCase(repository: di.resolve(ProtoRepositoryProtocol.self)!)
        }
        
        di.register(LoadSavedProtosUseCase.self) {
            LoadSavedProtosUseCase(
                importProtoFileUseCase: di.resolve(ImportProtoFileUseCaseProtocol.self)!
            )
        }
        
        di.register(CreateEditorTabUseCase.self) {
            CreateEditorTabUseCase()
        }
        
        di.register(GenerateMockDataUseCase.self) {
            GenerateMockDataUseCase(
                mockDataGenerator: di.resolve(MockDataGeneratorProtocol.self)!
            )
        }
        
        di.register(ExecuteUnaryRequestUseCaseProtocol.self) {
            ExecuteUnaryRequestUseCase(
                grpcClient: di.resolve(GrpcClientProtocol.self)!
            )
        }
        
        // Create SidebarViewModel once
        let sidebarVM = SidebarViewModel(
            importProtoFileUseCase: di.resolve(ImportProtoFileUseCaseProtocol.self)!,
            importPathsRepository: di.resolve(ImportPathsRepositoryProtocol.self)!,
            protoPathsPersistence: di.resolve(ProtoPathsPersistenceProtocol.self)!,
            loadSavedProtosUseCase: di.resolve(LoadSavedProtosUseCase.self)!
        )
        
        // Create AppViewModel
        let appVM = AppViewModel(
            createEditorTabUseCase: di.resolve(CreateEditorTabUseCase.self)!,
            generateMockDataUseCase: di.resolve(GenerateMockDataUseCase.self)!,
            executeRequestUseCase: di.resolve(ExecuteUnaryRequestUseCaseProtocol.self)!
        )
        
        // Use _StateObject to initialize @StateObject properties
        _sidebarViewModel = StateObject(wrappedValue: sidebarVM)
        _appViewModel = StateObject(wrappedValue: appVM)
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            NavigationSplitView {
                SidebarView(
                    viewModel: sidebarViewModel,
                    onMethodSelected: { method, service, protoFile in
                        appViewModel.openMethod(method: method, service: service, protoFile: protoFile)
                    }
                )
                .task {
                    // Load saved proto files on app startup
                    await sidebarViewModel.loadSavedProtos()
                }
            } detail: {
                if let editorTab = appViewModel.selectedEditorTab {
                    RequestEditorView(viewModel: editorTab)
                } else {
                    placeholderView
                }
            }
            .frame(minWidth: 900, minHeight: 600)
            .environmentObject(di)
        }
    }
    
    // MARK: - Subviews
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Select a method to start")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
