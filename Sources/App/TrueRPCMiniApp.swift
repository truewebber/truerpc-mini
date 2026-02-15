import SwiftUI

@main
struct TrueRPCMiniApp: App {
    // MARK: - Properties
    
    /// Dependency Injection container
    private let di: AppDI
    
    /// Sidebar ViewModel (created once and reused)
    @StateObject private var sidebarViewModel: SidebarViewModel
    
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
        
        // Register Domain Layer dependencies
        di.register(ImportProtoFileUseCaseProtocol.self) {
            ImportProtoFileUseCase(repository: di.resolve(ProtoRepositoryProtocol.self)!)
        }
        
        di.register(LoadSavedProtosUseCase.self) {
            LoadSavedProtosUseCase(
                importProtoFileUseCase: di.resolve(ImportProtoFileUseCaseProtocol.self)!
            )
        }
        
        // Create SidebarViewModel once
        let viewModel = SidebarViewModel(
            importProtoFileUseCase: di.resolve(ImportProtoFileUseCaseProtocol.self)!,
            importPathsRepository: di.resolve(ImportPathsRepositoryProtocol.self)!,
            protoPathsPersistence: di.resolve(ProtoPathsPersistenceProtocol.self)!,
            loadSavedProtosUseCase: di.resolve(LoadSavedProtosUseCase.self)!
        )
        
        // Use _StateObject to initialize @StateObject property
        _sidebarViewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                SidebarView(viewModel: sidebarViewModel)
                    .task {
                        // Load saved proto files on app startup
                        await sidebarViewModel.loadSavedProtos()
                    }
                
                Text("Select a method to start")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 800, minHeight: 600)
            .environmentObject(di)
        }
    }
}
