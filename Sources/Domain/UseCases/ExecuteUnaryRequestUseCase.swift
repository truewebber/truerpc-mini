import Foundation

/// Use case for executing unary gRPC requests
/// Validates input and delegates to gRPC client
public protocol ExecuteUnaryRequestUseCaseProtocol {
    func execute(request: RequestDraft, method: TrueRPCMini.Method) async throws -> GrpcResponse
}

public class ExecuteUnaryRequestUseCase: ExecuteUnaryRequestUseCaseProtocol {
    private let grpcClient: GrpcClientProtocol
    
    public init(grpcClient: GrpcClientProtocol) {
        self.grpcClient = grpcClient
    }
    
    public func execute(request: RequestDraft, method: TrueRPCMini.Method) async throws -> GrpcResponse {
        // Validate JSON syntax
        guard let jsonData = request.jsonBody.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
            throw GrpcClientError.invalidJSON("Invalid JSON syntax")
        }
        
        // Execute request via gRPC client
        return try await grpcClient.executeUnary(request: request, method: method)
    }
}
