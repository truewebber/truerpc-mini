import Foundation

/// Represents gRPC metadata (headers) to be sent with requests
/// gRPC metadata is key-value pairs sent alongside the request
/// Binary metadata keys must end with "-bin" suffix
public struct GrpcMetadata: Equatable {
    /// Dictionary of metadata key-value pairs
    public let headers: [String: String]
    
    /// Create empty metadata
    public init() {
        self.headers = [:]
    }
    
    /// Create metadata with headers
    /// - Parameter headers: Dictionary of key-value pairs
    public init(headers: [String: String]) {
        self.headers = headers
    }
    
    /// Check if a key represents binary metadata
    /// Binary keys must end with "-bin" suffix according to gRPC spec
    /// - Parameter key: The metadata key to check
    /// - Returns: true if key ends with "-bin"
    public static func isBinaryKey(_ key: String) -> Bool {
        return key.hasSuffix("-bin")
    }
    
    /// Parse metadata from JSON string
    /// - Parameter json: JSON string representing key-value pairs
    /// - Returns: GrpcMetadata instance
    /// - Throws: Error if JSON is invalid or not an object
    public static func from(json: String) throws -> GrpcMetadata {
        guard let data = json.data(using: .utf8) else {
            throw GrpcMetadataError.invalidJSON
        }
        
        let parsed = try JSONSerialization.jsonObject(with: data)
        
        guard let headers = parsed as? [String: String] else {
            throw GrpcMetadataError.notAnObject
        }
        
        return GrpcMetadata(headers: headers)
    }
    
    /// Convert metadata to JSON string
    /// - Returns: JSON string representation
    /// - Throws: Error if serialization fails
    public func toJSON() throws -> String {
        if headers.isEmpty {
            return "{}"
        }
        
        let data = try JSONSerialization.data(
            withJSONObject: headers,
            options: [.sortedKeys, .prettyPrinted]
        )
        
        guard let json = String(data: data, encoding: .utf8) else {
            throw GrpcMetadataError.serializationFailed
        }
        
        return json
    }
}

/// Errors that can occur during metadata operations
public enum GrpcMetadataError: Error, Equatable {
    case invalidJSON
    case notAnObject
    case serializationFailed
}
