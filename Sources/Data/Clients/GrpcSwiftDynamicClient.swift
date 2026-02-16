import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import SwiftProtoReflect

/// Dynamic gRPC client that uses SwiftProtoReflect for message handling
/// and grpc-swift-2 for transport
public class GrpcSwiftDynamicClient: GrpcClientProtocol {
    private let protoRepository: ProtoRepositoryProtocol
    
    public init(protoRepository: ProtoRepositoryProtocol) {
        self.protoRepository = protoRepository
    }
    
    /// Execute a unary gRPC request
    public func executeUnary(
        request: RequestDraft,
        method: TrueRPCMini.Method
    ) async throws -> GrpcResponse {
        let startTime = Date()
        
        // 1. Get message descriptors from proto repository
        let inputDescriptor = try protoRepository.getMessageDescriptor(forType: method.inputType)
        let outputDescriptor = try protoRepository.getMessageDescriptor(forType: method.outputType)
        
        // 2. Parse JSON to DynamicMessage
        let inputMessage = try parseJSON(request.jsonBody, using: inputDescriptor)
        
        // 3. Parse URL to extract host and port
        let (host, port) = try parseServerAddress(request.url)
        
        // 4. Determine if TLS should be used (default for 443)
        let useTLS = shouldUseTLS(port: port, url: request.url)
        
        do {
            // 5. Create transport and execute with client
            return try await withGRPCClient(
                transport: try .http2NIOPosix(
                    target: .dns(host: host, port: port),
                    transportSecurity: useTLS ? .tls : .plaintext,
                    config: .defaults
                )
            ) { client in
                // 5. Create method descriptor for gRPC
                let methodDescriptor = MethodDescriptor(
                    fullyQualifiedService: method.serviceName,
                    method: method.name
                )
                
                // 6. Create serializers
                let serializer = DynamicMessageSerializer()
                let deserializer = DynamicMessageDeserializer(messageDescriptor: outputDescriptor)
                
                // 7. Create client request with metadata
                var clientRequest = ClientRequest(message: inputMessage)
                if let metadata = request.metadata {
                    clientRequest.metadata = convertToGrpcMetadata(metadata)
                }
                
                // 8. Execute unary call
                return try await client.unary(
                    request: clientRequest,
                    descriptor: methodDescriptor,
                    serializer: serializer,
                    deserializer: deserializer,
                    options: .defaults
                ) { response in
                    // 9. Convert response message to JSON
                    let responseJSON = try self.messageToJSON(response.message)
                    let responseTime = Date().timeIntervalSince(startTime)
                    
                    return GrpcResponse(
                        jsonBody: responseJSON,
                        responseTime: responseTime,
                        statusCode: 0, // Success
                        statusMessage: "OK"
                    )
                }
            }
        } catch let error as RPCError {
            // Handle gRPC-specific errors
            throw mapGrpcError(error)
        } catch {
            // Handle other errors
            throw GrpcClientError.unknown(error.localizedDescription)
        }
    }
    
    /// Determine if TLS should be used based on port
    /// Standard gRPC convention: port 443 = TLS, other ports = plaintext
    internal func shouldUseTLS(port: Int, url: String) -> Bool {
        return port == 443
    }
    
    /// Parse server address into host and port
    internal func parseServerAddress(_ address: String) throws -> (host: String, port: Int) {
        // gRPC doesn't use http:// or https:// prefixes, but clean them if present
        let cleanAddress = address
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        let components = cleanAddress.split(separator: ":")
        
        guard !components.isEmpty else {
            throw GrpcClientError.networkError("Invalid server address: \(address)")
        }
        
        let host = String(components[0])
        let port = components.count > 1 ? Int(components[1]) ?? 50051 : 50051
        
        return (host, port)
    }
    
    /// Map gRPC RPCError to GrpcClientError
    internal func mapGrpcError(_ error: RPCError) -> GrpcClientError {
        switch error.code {
        case .unavailable:
            return .unavailable
        case .deadlineExceeded:
            return .timeout
        default:
            return .networkError("gRPC error: \(error.code) - \(error.message)")
        }
    }
    
    /// Parse JSON string to DynamicMessage using descriptor
    func parseJSON(_ jsonString: String, using descriptor: MessageDescriptor) throws -> DynamicMessage {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GrpcClientError.invalidJSON("Cannot convert string to data")
        }
        
        let deserializer = JSONDeserializer()
        return try deserializer.deserialize(jsonData, using: descriptor)
    }
    
    /// Convert DynamicMessage to JSON string
    func messageToJSON(_ message: DynamicMessage) throws -> String {
        let serializer = JSONSerializer()
        let data = try serializer.serialize(message)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw GrpcClientError.invalidResponse
        }
        return jsonString
    }
    
    /// Convert TrueRPCMini.GrpcMetadata to GRPCCore.Metadata
    private func convertToGrpcMetadata(_ metadata: TrueRPCMini.GrpcMetadata) -> GRPCCore.Metadata {
        var grpcMetadata = GRPCCore.Metadata()
        
        for (key, value) in metadata.headers {
            // Check if this is binary metadata (keys ending with "-bin")
            if TrueRPCMini.GrpcMetadata.isBinaryKey(key) {
                // Binary metadata - encode as bytes
                if let data = value.data(using: .utf8) {
                    grpcMetadata.addBinary([UInt8](data), forKey: key)
                }
            } else {
                // String metadata
                grpcMetadata.addString(value, forKey: key)
            }
        }
        
        return grpcMetadata
    }
}
