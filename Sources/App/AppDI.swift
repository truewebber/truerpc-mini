import Foundation

/// Dependency Injection Container for the application.
/// Manages service registration and resolution with support for different lifecycles.
public final class AppDI: ObservableObject {
    
    // MARK: - Lifecycle
    
    /// Defines the lifecycle of a registered service
    public enum Lifecycle {
        /// Creates a new instance every time the service is resolved
        case transient
        /// Creates a single shared instance that is reused for all resolutions
        case singleton
    }
    
    // MARK: - Private Properties
    
    /// Stores factory closures for registered services
    private var factories: [String: () -> Any] = [:]
    
    /// Stores lifecycle configuration for registered services
    private var lifecycles: [String: Lifecycle] = [:]
    
    /// Caches singleton instances
    private var singletons: [String: Any] = [:]
    
    /// Singleton instance of the container itself
    private static var shared: AppDI?
    
    // MARK: - Initialization
    
    public init() {
        Self.shared = self
    }
    
    // MARK: - Public Methods
    
    /// Registers a service with the container
    /// - Parameters:
    ///   - type: The protocol or type to register
    ///   - lifecycle: The lifecycle of the service (default: .singleton)
    ///   - factory: A closure that creates an instance of the service
    public func register<T>(_ type: T.Type, lifecycle: Lifecycle = .singleton, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
        lifecycles[key] = lifecycle
    }
    
    /// Resolves a service from the container
    /// - Parameter type: The protocol or type to resolve
    /// - Returns: An instance of the service, or nil if not registered
    public func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        guard let factory = factories[key] else {
            return nil
        }
        
        let lifecycle = lifecycles[key] ?? .singleton
        
        switch lifecycle {
        case .singleton:
            if let cached = singletons[key] as? T {
                return cached
            }
            let instance = factory() as! T
            singletons[key] = instance
            return instance
            
        case .transient:
            return factory() as? T
        }
    }
    
    /// Resolves the singleton container instance
    /// - Returns: The shared AppDI instance
    public func resolve() -> AppDI {
        return self
    }
    
    /// Clears all registrations and cached instances
    public func reset() {
        factories.removeAll()
        lifecycles.removeAll()
        singletons.removeAll()
    }
}
