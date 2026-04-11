import Foundation

/// One autocomplete option derived from the proto schema at a given context.
public struct AutocompleteSuggestion: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let typeHint: String
    public let kind: SuggestionKind
    public let oneOfGroup: String?
    /// The text to actually insert, when different from `name`.
    /// Used by `.wktDefault` suggestions whose display name is "insert default value"
    /// but whose inserted text is the RFC 3339 / duration string.
    public let insertValue: String?

    public init(
        id: UUID = UUID(),
        name: String,
        typeHint: String,
        kind: SuggestionKind,
        oneOfGroup: String? = nil,
        insertValue: String? = nil)
    {
        self.id = id
        self.name = name
        self.typeHint = typeHint
        self.kind = kind
        self.oneOfGroup = oneOfGroup
        self.insertValue = insertValue
    }
}
