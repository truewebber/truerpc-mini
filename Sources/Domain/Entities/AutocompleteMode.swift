/// Where in a JSON document the user is editing, for autocomplete resolution.
public enum AutocompleteMode: Equatable, Sendable {
    case key
    case enumValue
    case arrayElement
}
