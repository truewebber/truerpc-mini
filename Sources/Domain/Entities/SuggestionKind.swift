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
    /// A well-known-type field in key-mode (Timestamp, Duration). Inserts `"fieldName": ""`
    /// and re-triggers autocomplete so that WKT default-value suggestions appear immediately.
    case wktString
    /// A default value for a well-known type (Timestamp, Duration) in value-position.
    /// Inserts the quoted RFC 3339 / duration string stored in `AutocompleteSuggestion.insertValue`.
    case wktDefault
    case fillDefaults
}
