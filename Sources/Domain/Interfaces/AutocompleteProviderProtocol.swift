/// Supplies JSON-body autocomplete options derived from a loaded proto schema.
public protocol AutocompleteProviderProtocol: Sendable {
    /// Returns schema-derived suggestions for the given edit context.
    /// - Parameter rootMessageType: The fully-qualified input type of the method being edited
    ///   (e.g. `.mypackage.MyRequest`). Used as the root of schema traversal.
    func suggestions(
        for context: AutocompleteContext,
        rootMessageType: String,
        in protoFile: ProtoFile)
        async -> [AutocompleteSuggestion]

    /// The type name for an empty value at `context`, or `nil` when the caret is not on a field value.
    func valueTypeHint(
        for context: AutocompleteContext,
        rootMessageType: String,
        in protoFile: ProtoFile)
        async -> JsonValueTypeHint?
}

public extension AutocompleteProviderProtocol {
    func valueTypeHint(
        for _: AutocompleteContext,
        rootMessageType _: String,
        in _: ProtoFile)
        -> JsonValueTypeHint?
    {
        nil
    }
}
