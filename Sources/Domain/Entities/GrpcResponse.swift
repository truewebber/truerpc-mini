import Foundation

/// Represents the result of a gRPC request execution
/// Contains response data, timing, status information, and metadata
public struct GrpcResponse: Equatable {
    public let jsonBody: String
    public let responseTime: TimeInterval
    public let statusCode: Int
    public let statusMessage: String
    public let headers: [String: String]?
    public let trailers: [String: String]?
    public let statusDetails: String?
    
    public init(
        jsonBody: String,
        responseTime: TimeInterval,
        statusCode: Int,
        statusMessage: String,
        headers: [String: String]? = nil,
        trailers: [String: String]? = nil,
        statusDetails: String? = nil
    ) {
        self.jsonBody = jsonBody
        self.responseTime = responseTime
        self.statusCode = statusCode
        self.statusMessage = statusMessage
        self.headers = headers
        self.trailers = trailers
        self.statusDetails = statusDetails
    }
}
