/// Classification of an autocomplete entry for display and behaviour.
public enum SuggestionKind: Equatable, Sendable {
    case message
    case string
    case number
    case bool
    case `enum`
    case repeated
    case fillDefaults
}
