import Foundation

/// Represents a gRPC request execution with its lifecycle
/// Tracks the request, timestamp, and current execution status
public struct RequestExecution: Equatable {
    public let id: UUID
    public let request: RequestDraft
    public let timestamp: Date
    public let status: ExecutionStatus
    
    public init(
        id: UUID = UUID(),
        request: RequestDraft,
        timestamp: Date = Date(),
        status: ExecutionStatus
    ) {
        self.id = id
        self.request = request
        self.timestamp = timestamp
        self.status = status
    }
    
    /// The current status of the request execution
    public enum ExecutionStatus: Equatable {
        case pending
        case executing
        case success(GrpcResponse)
        case failure(String)
    }
}
