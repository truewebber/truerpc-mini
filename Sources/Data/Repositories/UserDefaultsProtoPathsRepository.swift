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
    }
    
    public func getProtoPaths() -> [URL] {
        guard let pathStrings = userDefaults.stringArray(forKey: key) else {
            return []
        }
        
        return pathStrings.map { URL(fileURLWithPath: $0) }
    }
}
