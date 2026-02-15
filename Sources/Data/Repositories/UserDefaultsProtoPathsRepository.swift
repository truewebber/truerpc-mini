import Foundation

/// Repository for persisting proto file paths using UserDefaults
public final class UserDefaultsProtoPathsRepository: ProtoPathsPersistenceProtocol {
    private let userDefaults: UserDefaults
    private let key: String
    
    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "com.truewebber.TrueRPCMini.protoPaths"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }
    
    public func saveProtoPaths(_ paths: [URL]) {
        let pathStrings = paths.map { $0.path }
        userDefaults.set(pathStrings, forKey: key)
        userDefaults.synchronize()
        print("DEBUG: Saved \(pathStrings.count) proto paths: \(pathStrings)")
    }
    
    public func getProtoPaths() -> [URL] {
        guard let pathStrings = userDefaults.stringArray(forKey: key) else {
            print("DEBUG: No saved proto paths found")
            return []
        }
        
        print("DEBUG: Loaded \(pathStrings.count) proto paths: \(pathStrings)")
        return pathStrings.map { URL(fileURLWithPath: $0) }
    }
}
