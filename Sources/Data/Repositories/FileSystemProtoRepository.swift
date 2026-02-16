import Foundation
import SwiftProtoParser
import SwiftProtobuf
import SwiftProtoReflect

/// Repository for loading proto files from the file system
/// Implements ProtoRepositoryProtocol from Domain layer
public final class FileSystemProtoRepository: ProtoRepositoryProtocol {
    private var loadedProtos: [ProtoFile] = []
    private var fileDescriptors: [Google_Protobuf_FileDescriptorProto] = []
    
    public init() {}
    
    public func loadProto(url: URL) async throws -> ProtoFile {
        // Parse proto file using SwiftProtoParser without import path resolution
        let result = SwiftProtoParser.parseProtoToDescriptors(url.path)
        
        switch result {
        case .success(let fileDescriptor):
            // Store file descriptor for later use
            fileDescriptors.append(fileDescriptor)
            
            // Map to Domain entity
            let protoFile = mapToProtoFile(fileDescriptor: fileDescriptor, url: url)
            
            // Store loaded proto
            loadedProtos.append(protoFile)
            
            return protoFile
            
        case .failure(let error):
            throw ProtoRepositoryError.parsingFailed(error.localizedDescription)
        }
    }
    
    public func loadProto(url: URL, importPaths: [String]) async throws -> ProtoFile {
        // Parse proto file using SwiftProtoParser with import path resolution
        let result = SwiftProtoParser.parseProtoFileWithImportsToDescriptors(
            url.path,
            importPaths: importPaths
        )
        
        switch result {
        case .success(let fileDescriptor):
            // Store file descriptor for later use
            fileDescriptors.append(fileDescriptor)
            
            // Map to Domain entity
            let protoFile = mapToProtoFile(fileDescriptor: fileDescriptor, url: url)
            
            // Store loaded proto
            loadedProtos.append(protoFile)
            
            return protoFile
            
        case .failure(let error):
            throw ProtoRepositoryError.parsingFailed(error.localizedDescription)
        }
    }
    
    public func getLoadedProtos() -> [ProtoFile] {
        return loadedProtos
    }
    
    public func getMessageDescriptor(forType typeName: String) throws -> MessageDescriptor {
        // Normalize type name - remove leading dot if present
        let normalizedTypeName = typeName.hasPrefix(".") ? String(typeName.dropFirst()) : typeName
        
        // Search through all loaded file descriptors
        for fileDescriptor in fileDescriptors {
            // Try searching with the file's package
            if let descriptor = try? findMessageDescriptor(
                in: fileDescriptor,
                typeName: normalizedTypeName,
                package: fileDescriptor.package
            ) {
                return descriptor
            }
            
            // If not found, try stripping the first package component
            // e.g., "example.google.protobuf.Empty" -> "google.protobuf.Empty"
            if normalizedTypeName.contains(".") {
                let components = normalizedTypeName.split(separator: ".")
                if components.count > 1 {
                    // Try removing first component
                    let withoutFirstPackage = components.dropFirst().joined(separator: ".")
                    
                    if let descriptor = try? findMessageDescriptor(
                        in: fileDescriptor,
                        typeName: withoutFirstPackage,
                        package: fileDescriptor.package
                    ) {
                        return descriptor
                    }
                }
            }
        }
        
        throw ProtoRepositoryError.messageTypeNotFound(typeName)
    }
    
    // MARK: - Private Helpers
    
    /// Recursively find message descriptor by type name
    private func findMessageDescriptor(
        in fileDescriptor: Google_Protobuf_FileDescriptorProto,
        typeName: String,
        package: String
    ) throws -> MessageDescriptor? {
        // Build fully qualified name prefix
        let packagePrefix = package.isEmpty ? "" : "\(package)."
        
        // Search through messages in file descriptor
        for messageType in fileDescriptor.messageType {
            let fullName = packagePrefix + messageType.name
            
            if fullName == typeName || messageType.name == typeName {
                // Found it! Convert to SwiftProtoReflect MessageDescriptor
                return try convertToMessageDescriptor(messageType, package: package)
            }
            
            // Search in nested types
            if let nested = try findNestedMessageDescriptor(
                in: messageType,
                typeName: typeName,
                parentName: fullName
            ) {
                return nested
            }
        }
        
        return nil
    }
    
    /// Find message descriptor in nested types
    private func findNestedMessageDescriptor(
        in messageType: Google_Protobuf_DescriptorProto,
        typeName: String,
        parentName: String
    ) throws -> MessageDescriptor? {
        for nestedType in messageType.nestedType {
            let fullName = "\(parentName).\(nestedType.name)"
            
            if fullName == typeName || nestedType.name == typeName {
                return try convertToMessageDescriptor(nestedType, package: parentName)
            }
            
            // Recurse deeper
            if let deeper = try findNestedMessageDescriptor(
                in: nestedType,
                typeName: typeName,
                parentName: fullName
            ) {
                return deeper
            }
        }
        
        return nil
    }
    
    /// Convert Google_Protobuf_DescriptorProto to SwiftProtoReflect MessageDescriptor
    private func convertToMessageDescriptor(
        _ protoDescriptor: Google_Protobuf_DescriptorProto,
        package: String
    ) throws -> MessageDescriptor {
        // Create file descriptor for SwiftProtoReflect
        let fileDesc = FileDescriptor(
            name: "dynamic.proto",
            package: package
        )
        
        // Create message descriptor
        var messageDesc = MessageDescriptor(
            name: protoDescriptor.name,
            parent: fileDesc
        )
        
        // Add fields
        for field in protoDescriptor.field {
            let fieldDesc = try convertToFieldDescriptor(field)
            messageDesc.addField(fieldDesc)
        }
        
        return messageDesc
    }
    
    /// Convert Google_Protobuf_FieldDescriptorProto to SwiftProtoReflect FieldDescriptor
    private func convertToFieldDescriptor(
        _ fieldProto: Google_Protobuf_FieldDescriptorProto
    ) throws -> FieldDescriptor {
        let fieldType = convertFieldType(fieldProto.type)
        
        // Check if field is repeated
        let isRepeated = fieldProto.label == .repeated
        
        // For message and enum types, we need to provide the typeName
        if fieldType == .message || fieldType == .enum {
            let typeName = fieldProto.typeName.hasPrefix(".") 
                ? String(fieldProto.typeName.dropFirst()) 
                : fieldProto.typeName
            
            return FieldDescriptor(
                name: fieldProto.name,
                number: Int(fieldProto.number),
                type: fieldType,
                typeName: typeName,
                isRepeated: isRepeated
            )
        }
        
        return FieldDescriptor(
            name: fieldProto.name,
            number: Int(fieldProto.number),
            type: fieldType,
            isRepeated: isRepeated
        )
    }
    
    /// Convert protobuf field type to SwiftProtoReflect FieldType
    private func convertFieldType(_ type: Google_Protobuf_FieldDescriptorProto.TypeEnum) -> SwiftProtoReflect.FieldType {
        switch type {
        case .double: return .double
        case .float: return .float
        case .int64: return .int64
        case .uint64: return .uint64
        case .int32: return .int32
        case .fixed64: return .fixed64
        case .fixed32: return .fixed32
        case .bool: return .bool
        case .string: return .string
        case .group: return .message // Treat group as message
        case .message: return .message
        case .bytes: return .bytes
        case .uint32: return .uint32
        case .enum: return .enum
        case .sfixed32: return .sfixed32
        case .sfixed64: return .sfixed64
        case .sint32: return .sint32
        case .sint64: return .sint64
        @unknown default: return .string // Fallback
        }
    }
    
    // MARK: - Private Mapping
    
    private func mapToProtoFile(
        fileDescriptor: Google_Protobuf_FileDescriptorProto,
        url: URL
    ) -> ProtoFile {
        let services = fileDescriptor.service.map { serviceDesc in
            mapToService(serviceDescriptor: serviceDesc, package: fileDescriptor.package)
        }
        
        return ProtoFile(
            name: url.lastPathComponent,
            path: url,
            services: services
        )
    }
    
    private func mapToService(
        serviceDescriptor: Google_Protobuf_ServiceDescriptorProto,
        package: String
    ) -> Service {
        // Construct fully qualified service name: package.ServiceName
        let fullServiceName = package.isEmpty ? serviceDescriptor.name : "\(package).\(serviceDescriptor.name)"
        
        let methods = serviceDescriptor.method.map { methodDesc in
            mapToMethod(methodDescriptor: methodDesc, serviceName: fullServiceName)
        }
        
        return Service(
            name: serviceDescriptor.name,
            methods: methods
        )
    }
    
    private func mapToMethod(
        methodDescriptor: Google_Protobuf_MethodDescriptorProto,
        serviceName: String
    ) -> Method {
        return Method(
            name: methodDescriptor.name,
            serviceName: serviceName,
            inputType: methodDescriptor.inputType,
            outputType: methodDescriptor.outputType,
            isStreaming: methodDescriptor.clientStreaming || methodDescriptor.serverStreaming
        )
    }
}

// MARK: - Error Types

public enum ProtoRepositoryError: Error, Equatable {
    case parsingFailed(String)
    case fileNotFound
    case messageTypeNotFound(String)
}

extension ProtoRepositoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .parsingFailed(let message):
            return "Failed to parse proto file: \(message)"
        case .fileNotFound:
            return "Proto file not found"
        case .messageTypeNotFound(let typeName):
            return "Message type '\(typeName)' not found in loaded proto files"
        }
    }
}
