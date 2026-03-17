import Foundation

/// Use case for executing unary gRPC requests.
/// Validates input, fires telemetry events at lifecycle points, and delegates to gRPC client.
public protocol ExecuteUnaryRequestUseCaseProtocol: Sendable {
    func execute(request: RequestDraft, method: TrueRPCMini.Method) async throws -> GrpcResponse
}

public final class ExecuteUnaryRequestUseCase: ExecuteUnaryRequestUseCaseProtocol {
    private let grpcClient: GrpcClientProtocol
    private let telemetry: TelemetryServiceProtocol

    public init(grpcClient: GrpcClientProtocol, telemetry: TelemetryServiceProtocol) {
        self.grpcClient = grpcClient
        self.telemetry = telemetry
    }

    public func execute(request: RequestDraft, method: TrueRPCMini.Method) async throws -> GrpcResponse {
        let normalizedJson = normalizeSmartQuotes(request.jsonBody)

        guard let jsonData = normalizedJson.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: jsonData)
        else {
            throw GrpcClientError.invalidJSON("Invalid JSON syntax")
        }

        let normalizedRequest = RequestDraft(
            jsonBody: normalizedJson,
            url: request.url,
            method: request.method,
            metadata: request.metadata,
            tlsConfiguration: request.tlsConfiguration)

        await telemetry.track(.requestSent(serviceName: method.serviceName, methodName: method.name))

        do {
            let response = try await grpcClient.executeUnary(request: normalizedRequest, method: method)
            let durationMs = Int(response.responseTime * 1000)
            await telemetry.track(.requestSucceeded(
                serviceName: method.serviceName,
                methodName: method.name,
                durationMs: durationMs))
            return response
        } catch let error as GrpcClientError {
            await telemetry.track(.requestFailed(
                serviceName: method.serviceName,
                methodName: method.name,
                errorCode: grpcStatusCode(from: error)))
            throw error
        } catch {
            await telemetry.track(.requestFailed(
                serviceName: method.serviceName,
                methodName: method.name,
                errorCode: "UNKNOWN"))
            throw error
        }
    }

    private func grpcStatusCode(from error: GrpcClientError) -> String {
        switch error {
        case let .grpcError(code, _): code
        case .unavailable: "UNAVAILABLE"
        case .timeout: "DEADLINE_EXCEEDED"
        case .networkError: "UNAVAILABLE"
        case .invalidJSON: "INVALID_ARGUMENT"
        case .invalidResponse: "INTERNAL"
        case .unknown: "UNKNOWN"
        case .tlsConfigurationFailed: "INVALID_ARGUMENT"
        }
    }

    /// Normalizes smart quotes and other typographic characters to plain ASCII.
    /// This handles macOS TextEditor's automatic quote substitution.
    private func normalizeSmartQuotes(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{201C}", with: "\"") // Left double quote
            .replacingOccurrences(of: "\u{201D}", with: "\"") // Right double quote
            .replacingOccurrences(of: "\u{2018}", with: "'") // Left single quote
            .replacingOccurrences(of: "\u{2019}", with: "'") // Right single quote
            .replacingOccurrences(of: "\u{2014}", with: "-") // Em dash
            .replacingOccurrences(of: "\u{2013}", with: "-") // En dash
    }
}
