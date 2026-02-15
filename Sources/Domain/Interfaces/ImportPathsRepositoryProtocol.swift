import Foundation

/// Protocol defining the contract for import paths persistence
/// Manages directories used for resolving proto file dependencies
public protocol ImportPathsRepositoryProtocol {
    /// Retrieves the list of configured import paths
    /// - Returns: Array of absolute directory paths for proto imports
    func getImportPaths() -> [String]
    
    /// Saves the list of import paths
    /// - Parameter paths: Array of absolute directory paths
    func saveImportPaths(_ paths: [String])
}
