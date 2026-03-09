import Foundation

/// Repository for persisting ServerEnvironment configurations using UserDefaults
public final class UserDefaultsEnvironmentRepository: EnvironmentRepositoryProtocol {
    private let userDefaults: UserDefaults
    private let key: String
    private let selectedIdKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "com.truewebber.TrueRPCMini.environments",
        selectedIdKey: String = "com.truewebber.TrueRPCMini.selectedEnvironmentId")
    {
        self.userDefaults = userDefaults
        self.key = key
        self.selectedIdKey = selectedIdKey
    }

    public func save(_ environment: ServerEnvironment) {
        var all = loadAll()
        if let index = all.firstIndex(where: { $0.id == environment.id }) {
            all[index] = environment
        } else {
            all.append(environment)
        }
        persist(all)
    }

    public func delete(id: UUID) {
        var all = loadAll()
        all.removeAll { $0.id == id }
        persist(all)
    }

    public func getAll() -> [ServerEnvironment] {
        loadAll()
    }

    public func getSelectedId() -> UUID? {
        guard let uuidString = userDefaults.string(forKey: selectedIdKey) else { return nil }
        return UUID(uuidString: uuidString)
    }

    public func setSelectedId(_ id: UUID?) {
        if let id {
            userDefaults.set(id.uuidString, forKey: selectedIdKey)
        } else {
            userDefaults.removeObject(forKey: selectedIdKey)
        }
    }

    // MARK: - Private

    private func loadAll() -> [ServerEnvironment] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }

        return (try? JSONDecoder().decode([ServerEnvironment].self, from: data)) ?? []
    }

    private func persist(_ environments: [ServerEnvironment]) {
        guard let data = try? JSONEncoder().encode(environments) else { return }

        userDefaults.set(data, forKey: key)
    }
}
