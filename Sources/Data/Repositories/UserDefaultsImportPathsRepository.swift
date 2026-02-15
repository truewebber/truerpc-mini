import Foundation

/// Repository for persisting import paths using UserDefaults
/// Implements ImportPathsRepositoryProtocol from Domain layer
public final class UserDefaultsImportPathsRepository: ImportPathsRepositoryProtocol {
    private let userDefaults: UserDefaults
    private let storageKey = "com.truewebber.TrueRPCMini.importPaths"
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    public func getImportPaths() -> [String] {
        return userDefaults.stringArray(forKey: storageKey) ?? []
    }
    
    public func saveImportPaths(_ paths: [String]) {
        userDefaults.set(paths, forKey: storageKey)
    }
}
