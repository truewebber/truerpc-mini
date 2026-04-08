/// Classification of an autocomplete entry for display and behaviour.
public enum SuggestionKind: Equatable, Sendable {
    case message
    case string
    case number
    case bool
    /// A field whose type is an enum (key-mode insertion). Inserts `"fieldName": ` and
    /// re-triggers autocomplete so that enum-value suggestions appear immediately.
    case enumField
    /// An enum value (enumValue / arrayElement mode insertion). Inserts the quoted value string.
    case `enum`
    case repeated
    case fillDefaults
}
