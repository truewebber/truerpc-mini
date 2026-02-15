import Foundation

/// Represents a draft of a gRPC request being edited
/// Contains the current state of the request before execution
public struct RequestDraft: Equatable {
    public let jsonBody: String
    public let url: String
    public let method: Method
    
    public init(
        jsonBody: String,
        url: String,
        method: Method
    ) {
        self.jsonBody = jsonBody
        self.url = url
        self.method = method
    }
}
