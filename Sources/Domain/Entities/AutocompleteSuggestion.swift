import Foundation

/// One autocomplete option derived from the proto schema at a given context.
public struct AutocompleteSuggestion: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let typeHint: String
    public let kind: SuggestionKind
    public let oneOfGroup: String?

    public init(
        id: UUID = UUID(),
        name: String,
        typeHint: String,
        kind: SuggestionKind,
        oneOfGroup: String? = nil)
    {
        self.id = id
        self.name = name
        self.typeHint = typeHint
        self.kind = kind
        self.oneOfGroup = oneOfGroup
    }
}
