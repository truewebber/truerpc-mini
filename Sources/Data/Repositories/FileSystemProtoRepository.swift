import Foundation
import SwiftProtoParser
import SwiftProtobuf

/// Repository for loading proto files from the file system
/// Implements ProtoRepositoryProtocol from Domain layer
public final class FileSystemProtoRepository: ProtoRepositoryProtocol {
    private var loadedProtos: [ProtoFile] = []
    
    public init() {}
    
    public func loadProto(url: URL) async throws -> ProtoFile {
        // Parse proto file using SwiftProtoParser
        let result = SwiftProtoParser.parseProtoToDescriptors(url.path)
        
        switch result {
        case .success(let fileDescriptor):
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
    
    // MARK: - Private Mapping
    
    private func mapToProtoFile(
        fileDescriptor: Google_Protobuf_FileDescriptorProto,
        url: URL
    ) -> ProtoFile {
        let services = fileDescriptor.service.map { serviceDesc in
            mapToService(serviceDescriptor: serviceDesc)
        }
        
        return ProtoFile(
            name: url.lastPathComponent,
            path: url,
            services: services
        )
    }
    
    private func mapToService(
        serviceDescriptor: Google_Protobuf_ServiceDescriptorProto
    ) -> Service {
        let methods = serviceDescriptor.method.map { methodDesc in
            mapToMethod(methodDescriptor: methodDesc)
        }
        
        return Service(
            name: serviceDescriptor.name,
            methods: methods
        )
    }
    
    private func mapToMethod(
        methodDescriptor: Google_Protobuf_MethodDescriptorProto
    ) -> Method {
        return Method(
            name: methodDescriptor.name,
            inputType: methodDescriptor.inputType,
            outputType: methodDescriptor.outputType,
            isStreaming: methodDescriptor.clientStreaming || methodDescriptor.serverStreaming
        )
    }
}

// MARK: - Error Types

public enum ProtoRepositoryError: Error {
    case parsingFailed(String)
    case fileNotFound
}
