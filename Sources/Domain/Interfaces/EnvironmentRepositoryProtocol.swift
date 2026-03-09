import Foundation

/// Contract for persisting and retrieving ServerEnvironment configurations
public protocol EnvironmentRepositoryProtocol {
    /// Persists an environment. Creates a new entry if the id is unknown, updates otherwise.
    func save(_ environment: ServerEnvironment)
    /// Removes the environment with the given id. No-op if not found.
    func delete(id: UUID)
    /// Returns all persisted environments, ordered by insertion.
    func getAll() -> [ServerEnvironment]
    /// Returns the ID of the globally selected environment, or nil if none.
    func getSelectedId() -> UUID?
    /// Persists the globally selected environment ID. Pass nil to clear the selection.
    func setSelectedId(_ id: UUID?)
}
