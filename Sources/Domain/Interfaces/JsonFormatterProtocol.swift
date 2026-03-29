/// Contract for formatting a raw JSON string into a pretty-printed representation.
public protocol JsonFormatterProtocol: Sendable {
    func format(_ json: String) throws -> String
}

/// Errors thrown by `JsonFormatterProtocol` implementations.
public enum JsonFormatterError: Error, Equatable {
    case invalidJSON(String)
}
