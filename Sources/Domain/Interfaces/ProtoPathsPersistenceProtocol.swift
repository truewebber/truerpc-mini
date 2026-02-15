import Foundation

/// Protocol defining the contract for persisting proto file paths
/// Allows the application to remember which proto files were loaded
public protocol ProtoPathsPersistenceProtocol {
    /// Saves the list of proto file paths to persistent storage
    /// - Parameter paths: Array of URLs pointing to proto files
    func saveProtoPaths(_ paths: [URL])
    
    /// Retrieves the list of saved proto file paths
    /// - Returns: Array of URLs to proto files that were previously loaded
    func getProtoPaths() -> [URL]
}
