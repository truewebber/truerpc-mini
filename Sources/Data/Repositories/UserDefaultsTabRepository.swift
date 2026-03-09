import Foundation

/// Repository for persisting editor tab states using UserDefaults
public final class UserDefaultsTabRepository: TabPersistenceProtocol {
    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "com.truewebber.TrueRPCMini.tabStates")
    {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func saveTabStates(_ states: [EditorTabState]) {
        guard let data = try? JSONEncoder().encode(states) else { return }

        userDefaults.set(data, forKey: key)
    }

    public func getTabStates() -> [EditorTabState] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        return (try? JSONDecoder().decode([EditorTabState].self, from: data)) ?? []
    }
}
