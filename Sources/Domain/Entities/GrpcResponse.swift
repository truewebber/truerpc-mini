import Foundation

/// Represents the result of a gRPC request execution
/// Contains response data, timing, and status information
public struct GrpcResponse: Equatable {
    public let jsonBody: String
    public let responseTime: TimeInterval
    public let statusCode: Int
    public let statusMessage: String
    
    public init(
        jsonBody: String,
        responseTime: TimeInterval,
        statusCode: Int,
        statusMessage: String
    ) {
        self.jsonBody = jsonBody
        self.responseTime = responseTime
        self.statusCode = statusCode
        self.statusMessage = statusMessage
    }
}
