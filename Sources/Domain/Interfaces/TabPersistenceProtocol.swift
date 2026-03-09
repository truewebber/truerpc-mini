import Foundation

/// Contract for persisting editor tab metadata across app restarts
public protocol TabPersistenceProtocol {
    /// Saves the list of tab states to persistent storage
    /// - Parameter states: Array of EditorTabState to persist
    func saveTabStates(_ states: [EditorTabState])

    /// Retrieves the list of saved tab states
    /// - Returns: Array of EditorTabState that were previously saved
    func getTabStates() -> [EditorTabState]
}
