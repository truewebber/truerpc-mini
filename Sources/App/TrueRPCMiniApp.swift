import SwiftUI

@main
struct TrueRPCMiniApp: App {
    // MARK: - Properties
    
    /// Dependency Injection container
    private let di: AppDI
    
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
        
        // Register Domain Layer dependencies
        di.register(ImportProtoFileUseCaseProtocol.self) {
            ImportProtoFileUseCase(repository: di.resolve(ProtoRepositoryProtocol.self)!)
        }
        
        // Register Presentation Layer dependencies
        di.register(SidebarViewModel.self, lifecycle: .transient) {
            SidebarViewModel(
                importProtoFileUseCase: di.resolve(ImportProtoFileUseCaseProtocol.self)!,
                importPathsRepository: di.resolve(ImportPathsRepositoryProtocol.self)!
            )
        }
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                SidebarView(viewModel: di.resolve(SidebarViewModel.self)!)
                
                Text("Select a method to start")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 800, minHeight: 600)
            .environmentObject(di)
        }
    }
}
