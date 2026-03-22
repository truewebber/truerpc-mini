import Foundation

/// Protocol for gRPC client that executes dynamic requests
/// Abstracts the underlying gRPC transport implementation
public protocol GrpcClientProtocol: Sendable {
    /// Execute a unary gRPC request
    /// - Parameters:
    ///   - request: The request draft containing JSON body, URL, method, and optional metadata
    ///   - method: The gRPC method to invoke
    ///   - protoFile: The loaded proto file that defines the method (scopes descriptor lookup)
    /// - Returns: The gRPC response with JSON body and timing
    /// - Throws: GrpcClientError for various failure scenarios
    func executeUnary(
        request: RequestDraft,
        method: TrueRPCMini.Method,
        protoFile: ProtoFile)
        async throws -> GrpcResponse
}

/// Errors that can occur during gRPC client operations
public enum GrpcClientError: Error, Equatable {
    case invalidJSON(String)
    case networkError(String)
    case timeout
    case unavailable
    case invalidResponse
    case grpcError(String, response: GrpcResponse)
    case unknown(String)
    case tlsConfigurationFailed(reason: String)

    public static func == (lhs: GrpcClientError, rhs: GrpcClientError) -> Bool {
        switch (lhs, rhs) {
        case let (.invalidJSON(l), .invalidJSON(r)):
            l == r
        case let (.networkError(l), .networkError(r)):
            l == r
        case (.timeout, .timeout):
            true
        case (.unavailable, .unavailable):
            true
        case (.invalidResponse, .invalidResponse):
            true
        case let (.grpcError(lMsg, lResp), .grpcError(rMsg, rResp)):
            lMsg == rMsg && lResp == rResp
        case let (.unknown(l), .unknown(r)):
            l == r
        case let (.tlsConfigurationFailed(l), .tlsConfigurationFailed(r)):
            l == r
        default:
            false
        }
    }
}
