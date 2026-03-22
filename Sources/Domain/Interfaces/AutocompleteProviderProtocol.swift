/// Supplies JSON-body autocomplete options derived from a loaded proto schema.
public protocol AutocompleteProviderProtocol: Sendable {
    /// Returns schema-derived suggestions for the given edit context.
    func suggestions(for context: AutocompleteContext, in protoFile: ProtoFile) async -> [AutocompleteSuggestion]
}
