import Foundation

/// Represents an editor tab for a gRPC method
/// Each tab maintains state for editing and executing a single gRPC method
public struct EditorTab: Identifiable, Equatable {
    public let id: UUID
    public let methodName: String
    public let serviceName: String
    public let protoFile: ProtoFile
    public let method: Method
    
    public init(
        id: UUID = UUID(),
        methodName: String,
        serviceName: String,
        protoFile: ProtoFile,
        method: Method
    ) {
        self.id = id
        self.methodName = methodName
        self.serviceName = serviceName
        self.protoFile = protoFile
        self.method = method
    }
}
