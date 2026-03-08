import Foundation

/// Repository for persisting proto file paths using UserDefaults
public final class UserDefaultsProtoPathsRepository: ProtoPathsPersistenceProtocol {
    private let userDefaults: UserDefaults
    private let key: String
    private let logger: AppLogger

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "com.truewebber.TrueRPCMini.protoPaths",
        logger: AppLogger)
    {
        self.userDefaults = userDefaults
        self.key = key
        self.logger = logger
    }

    public func saveProtoPaths(_ paths: [URL]) {
        let pathStrings = paths.map(\.path)
        userDefaults.set(pathStrings, forKey: key)
        userDefaults.synchronize()
        logger.debug("Proto paths saved", metadata: ["count": "\(pathStrings.count)"])
    }

    public func getProtoPaths() -> [URL] {
        guard let pathStrings = userDefaults.stringArray(forKey: key) else {
            return []
        }

        logger.debug("Proto paths loaded", metadata: ["count": "\(pathStrings.count)"])
        return pathStrings.map { URL(fileURLWithPath: $0) }
    }
}
