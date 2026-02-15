import SwiftUI

@main
struct TrueRPCMiniApp: App {
    // MARK: - Properties
    
    /// Dependency Injection container
    private let di: AppDI
    
    // MARK: - Initialization
    
    init() {
        // Initialize DI container
        di = AppDI()
        
        // Register dependencies here
        // Example:
        // di.register(ProtoRepositoryProtocol.self) { FileSystemProtoRepository() }
        // di.register(ImportProtoFileUseCase.self) {
        //     ImportProtoFileUseCase(repository: di.resolve(ProtoRepositoryProtocol.self)!)
        // }
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(di) // Make DI available throughout the app
        }
    }
}
