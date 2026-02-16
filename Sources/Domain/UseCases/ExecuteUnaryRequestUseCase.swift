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
        // Normalize smart quotes to regular quotes
        let normalizedJson = normalizeSmartQuotes(request.jsonBody)
        
        // Validate JSON syntax
        guard let jsonData = normalizedJson.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
            throw GrpcClientError.invalidJSON("Invalid JSON syntax")
        }
        
        // Create normalized request
        let normalizedRequest = RequestDraft(
            jsonBody: normalizedJson,
            url: request.url,
            method: request.method
        )
        
        // Execute request via gRPC client
        return try await grpcClient.executeUnary(request: normalizedRequest, method: method)
    }
    
    /// Normalizes smart quotes and other typographic characters to plain ASCII
    /// This handles macOS TextEditor's automatic quote substitution
    private func normalizeSmartQuotes(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\u{201C}", with: "\"") // Left double quote
            .replacingOccurrences(of: "\u{201D}", with: "\"") // Right double quote
            .replacingOccurrences(of: "\u{2018}", with: "'")  // Left single quote
            .replacingOccurrences(of: "\u{2019}", with: "'")  // Right single quote
            .replacingOccurrences(of: "\u{2014}", with: "-")  // Em dash
            .replacingOccurrences(of: "\u{2013}", with: "-")  // En dash
    }
}
