import Foundation

/// Represents a gRPC method (RPC) definition
public struct Method: Equatable, Identifiable {
    public let id: UUID
    public let name: String
    public let serviceName: String
    public let inputType: String
    public let outputType: String
    public let isStreaming: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        serviceName: String = "",
        inputType: String,
        outputType: String,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.name = name
        self.serviceName = serviceName
        self.inputType = inputType
        self.outputType = outputType
        self.isStreaming = isStreaming
    }
}
