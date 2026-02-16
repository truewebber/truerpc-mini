import Foundation

/// Protocol for gRPC client that executes dynamic requests
/// Abstracts the underlying gRPC transport implementation
public protocol GrpcClientProtocol {
    /// Execute a unary gRPC request
    /// - Parameters:
    ///   - request: The request draft containing JSON body, URL, method, and optional metadata
    ///   - method: The gRPC method to invoke
    /// - Returns: The gRPC response with JSON body and timing
    /// - Throws: GrpcClientError for various failure scenarios
    func executeUnary(
        request: RequestDraft,
        method: TrueRPCMini.Method
    ) async throws -> GrpcResponse
}

/// Errors that can occur during gRPC client operations
public enum GrpcClientError: Error, Equatable {
    case invalidJSON(String)
    case networkError(String)
    case timeout
    case unavailable
    case invalidResponse
    case unknown(String)
}
