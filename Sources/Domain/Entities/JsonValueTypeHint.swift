import Foundation

/// The schema type drawn at an empty JSON value. It is not part of the document.
public struct JsonValueTypeHint: Equatable, Sendable {
    public let name: String
    public let kind: SuggestionKind

    public init(name: String, kind: SuggestionKind) {
        self.name = name
        self.kind = kind
    }
}
