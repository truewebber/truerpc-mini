import Foundation

/// Use Case for exporting gRPC response to file
/// Handles saving response JSON with optional metadata
open class ExportResponseUseCase {
    private let fileManager: FileManagerProtocol
    
    public init(fileManager: FileManagerProtocol) {
        self.fileManager = fileManager
    }
    
    /// Export response to file
    /// - Parameters:
    ///   - response: The gRPC response to export
    ///   - destination: Destination file URL
    ///   - includeMetadata: If true, wraps response with metadata (time, status)
    /// - Throws: Error if file write fails
    open func execute(
        response: GrpcResponse,
        destination: URL,
        includeMetadata: Bool = false
    ) async throws {
        let data: Data
        
        if includeMetadata {
            // Create wrapper with metadata
            let wrapper: [String: Any] = [
                "response": response.jsonBody,
                "responseTime": response.responseTime,
                "statusCode": response.statusCode,
                "statusMessage": response.statusMessage,
                "exportedAt": ISO8601DateFormatter().string(from: Date())
            ]
            
            data = try JSONSerialization.data(withJSONObject: wrapper, options: .prettyPrinted)
        } else {
            // Export raw JSON
            data = response.jsonBody.data(using: .utf8) ?? Data()
        }
        
        try fileManager.write(data, to: destination)
    }
    
    /// Generate default filename with timestamp
    /// Format: response_YYYYMMDD_HHMMSS.json
    public func generateDefaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        return "response_\(timestamp).json"
    }
}
