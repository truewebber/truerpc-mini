import Foundation

/// Protocol defining the contract for exporting gRPC responses to files
@MainActor
public protocol ExportResponseUseCaseProtocol: Sendable {
    /// Export response to file
    /// - Parameters:
    ///   - response: The gRPC response to export
    ///   - destination: Destination file URL
    ///   - includeMetadata: If true, wraps response with metadata (time, status)
    /// - Throws: Error if file write fails
    func execute(response: GrpcResponse, destination: URL, includeMetadata: Bool) throws

    /// Generate default filename with timestamp
    func generateDefaultFilename() -> String
}
