import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import SwiftProtoReflect

/// Dynamic gRPC client that uses SwiftProtoReflect for message handling
/// and grpc-swift-2 for transport
public final class GrpcSwiftDynamicClient: GrpcClientProtocol, Sendable {
    private let protoRepository: ProtoRepositoryProtocol
    private let logger: AppLogger

    public init(protoRepository: ProtoRepositoryProtocol, logger: AppLogger) {
        self.protoRepository = protoRepository
        self.logger = logger
    }

    /// Execute a unary gRPC request
    public func executeUnary(
        request: RequestDraft,
        method: TrueRPCMini.Method,
        protoFile: ProtoFile)
        async throws -> GrpcResponse
    {
        let startTime = Date()

        // 1. Get message descriptors from proto repository
        let inputDescriptor: MessageDescriptor
        let outputDescriptor: MessageDescriptor
        do {
            inputDescriptor = try await protoRepository.getMessageDescriptor(
                forType: method.inputType,
                in: protoFile)
            outputDescriptor = try await protoRepository.getMessageDescriptor(
                forType: method.outputType,
                in: protoFile)
        } catch {
            logger.error("Proto message descriptor not found", metadata: [
                "inputType": method.inputType,
                "service": method.serviceName,
                "method": method.name,
                "error": error.localizedDescription,
            ])
            throw error
        }

        // 2. Parse JSON to DynamicMessage (nested / repeated messages require a TypeRegistry)
        let typeRegistry: TypeRegistry
        do {
            typeRegistry = try await protoRepository.makeJSONTypeRegistry(for: protoFile)
        } catch {
            logger.error("Failed to build JSON type registry", metadata: [
                "service": method.serviceName,
                "method": method.name,
                "error": error.localizedDescription,
            ])
            throw error
        }

        let inputMessage: DynamicMessage
        do {
            inputMessage = try parseJSON(request.jsonBody, using: inputDescriptor, typeRegistry: typeRegistry)
        } catch {
            logger.error("Request serialization failed", metadata: [
                "service": method.serviceName,
                "method": method.name,
                "field_count": String(inputDescriptor.fields.count),
                "error": error.localizedDescription,
                "missing_field": "none",
                "type_mismatch": "none",
            ])
            throw error
        }

        // 3. Parse URL to extract host and port
        let (host, port) = try parseServerAddress(request.url)

        // 4. Build transport security from TLSConfiguration
        let transportSecurity = try buildTransportSecurity(from: request.tlsConfiguration)
        let targetHost = request.tlsConfiguration.sniOverride ?? host

        do {
            // 5. Create transport and execute with client
            return try await withGRPCClient(
                transport: .http2NIOPosix(
                    target: .dns(host: targetHost, port: port),
                    transportSecurity: transportSecurity,
                    config: .defaults))
            { client in
                // 5. Create method descriptor for gRPC
                let methodDescriptor = MethodDescriptor(
                    fullyQualifiedService: method.serviceName,
                    method: method.name)

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
                    options: .defaults)
                { response in
                    // 9. Convert response message to JSON
                    let responseJSON: String
                    do {
                        responseJSON = try self.messageToJSON(response.message)
                    } catch {
                        let responseBytes: Int = if let binaryData = try? BinarySerializer()
                            .serialize(response.message)
                        {
                            binaryData.count
                        } else {
                            0
                        }
                        self.logger.error("Response deserialization failed", metadata: [
                            "service": method.serviceName,
                            "method": method.name,
                            "error": error.localizedDescription,
                            "expected_type": method.outputType,
                            "response_size_bytes": String(responseBytes),
                        ])
                        throw error
                    }
                    let responseTime = Date().timeIntervalSince(startTime)

                    // 10. Extract metadata from response
                    let headers = self.convertMetadataToDict(response.metadata)
                    let trailers = self.convertMetadataToDict(response.trailingMetadata)

                    return GrpcResponse(
                        jsonBody: responseJSON,
                        responseTime: responseTime,
                        statusCode: 0, // Success
                        statusMessage: "OK",
                        headers: headers.isEmpty ? nil : headers,
                        trailers: trailers.isEmpty ? nil : trailers)
                }
            }
        } catch let error as RPCError {
            let responseTime = Date().timeIntervalSince(startTime)
            let trailers = convertMetadataToDict(error.metadata)

            logger.error("gRPC request failed", metadata: [
                "code": error.code.description,
                "message": error.message,
                "url": request.url,
            ])

            let errorResponse = GrpcResponse(
                jsonBody: error.message.isEmpty ? "{}" : #"{"error": "\#(error.message)"}"#,
                responseTime: responseTime,
                statusCode: error.code.rawValue,
                statusMessage: error.code.description,
                trailers: trailers.isEmpty ? nil : trailers,
                statusDetails: error.message)
            throw GrpcClientError.grpcError(error.code.description, response: errorResponse)
        } catch {
            logger.error("gRPC request failed with unknown error", metadata: [
                "error": error.localizedDescription,
                "url": request.url,
            ])
            throw GrpcClientError.unknown(error.localizedDescription)
        }
    }

    /// Translate a domain TLSConfiguration into the gRPC transport security value.
    /// Checks file existence for custom CA and mTLS scenarios before returning.
    func buildTransportSecurity(
        from tlsConfig: TrueRPCMini.TLSConfiguration)
        throws -> HTTP2ClientTransport.Posix.TransportSecurity
    {
        guard tlsConfig.isTLSEnabled else {
            return .plaintext
        }

        if tlsConfig.allowInsecure {
            return .tls { config in
                config.serverCertificateVerification = .noVerification
            }
        }

        if let clientCertURL = tlsConfig.clientCertURL,
           let clientKeyURL = tlsConfig.clientKeyURL
        {
            let certPath = clientCertURL.path
            let keyPath = clientKeyURL.path
            guard FileManager.default.fileExists(atPath: certPath) else {
                throw GrpcClientError.tlsConfigurationFailed(
                    reason: "Client certificate not found: \(certPath)")
            }
            guard FileManager.default.fileExists(atPath: keyPath) else {
                throw GrpcClientError.tlsConfigurationFailed(
                    reason: "Client key not found: \(keyPath)")
            }

            if let customCAURL = tlsConfig.customCAURL {
                let caPath = customCAURL.path
                guard FileManager.default.fileExists(atPath: caPath) else {
                    throw GrpcClientError.tlsConfigurationFailed(
                        reason: "Custom CA certificate not found: \(caPath)")
                }

                return .mTLS(
                    certificateChain: [.file(path: certPath, format: .pem)],
                    privateKey: .file(path: keyPath, format: .pem))
                { config in
                    config.trustRoots = .certificates([.file(path: caPath, format: .pem)])
                }
            }

            return .mTLS(
                certificateChain: [.file(path: certPath, format: .pem)],
                privateKey: .file(path: keyPath, format: .pem))
        }

        if let customCAURL = tlsConfig.customCAURL {
            let caPath = customCAURL.path
            guard FileManager.default.fileExists(atPath: caPath) else {
                throw GrpcClientError.tlsConfigurationFailed(
                    reason: "Custom CA certificate not found: \(caPath)")
            }

            return .tls { config in
                config.trustRoots = .certificates([.file(path: caPath, format: .pem)])
            }
        }

        return .tls
    }

    /// Parse server address into host and port
    func parseServerAddress(_ address: String) throws -> (host: String, port: Int) {
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
    func mapGrpcError(_ error: RPCError, trailers: [String: String]? = nil) -> GrpcClientError {
        let errorMessage = error.message.isEmpty ? error.code.description : error.message
        let trailersInfo = trailers?.isEmpty == false ? " (trailers: \(trailers?.count ?? 0) items)" : ""

        switch error.code {
        case .unavailable:
            return .unavailable
        case .deadlineExceeded:
            return .timeout
        default:
            return .networkError("gRPC error: \(error.code) - \(errorMessage)\(trailersInfo)")
        }
    }

    /// Parse JSON string to DynamicMessage using descriptor
    func parseJSON(
        _ jsonString: String,
        using descriptor: MessageDescriptor,
        typeRegistry: TypeRegistry)
        throws -> DynamicMessage
    {
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GrpcClientError.invalidJSON("Cannot convert string to data")
        }

        let options = JSONDeserializationOptions(
            ignoreUnknownFields: true,
            typeRegistry: typeRegistry)
        let deserializer = JSONDeserializer(options: options)

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        } catch {
            throw GrpcClientError.invalidJSON("Invalid JSON: \(error.localizedDescription)")
        }
        guard let rootObject = jsonObject as? [String: Any] else {
            throw GrpcClientError.invalidJSON("Request body must be a JSON object")
        }

        let normalized = try GrpcRequestProtobufJSONNormalizer.normalizeMessageObject(
            rootObject,
            descriptor: descriptor,
            typeRegistry: typeRegistry)

        return try deserializer.deserializeFromJSONObject(normalized, using: descriptor)
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

    /// Convert GRPCCore.Metadata to Dictionary
    private func convertMetadataToDict(_ metadata: GRPCCore.Metadata) -> [String: String] {
        var result: [String: String] = [:]

        for (key, value) in metadata {
            switch value {
            case let .string(stringValue):
                // Append string values (metadata can have multiple values per key)
                if let existing = result[key] {
                    result[key] = "\(existing), \(stringValue)"
                } else {
                    result[key] = stringValue
                }

            case let .binary(binaryValue):
                // Convert binary to base64 string
                let base64 = Data(binaryValue).base64EncodedString()
                if let existing = result[key] {
                    result[key] = "\(existing), \(base64)"
                } else {
                    result[key] = base64
                }
            }
        }

        return result
    }
}
