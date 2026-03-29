/// Contract for resolving a JSON cursor position to autocomplete context.
public protocol JsonPathResolverProtocol: Sendable {
    func resolve(json: String, cursorOffset: Int) -> AutocompleteContext
    func collectKeysAfterCursor(json: String, cursorOffset: Int) -> Set<String>
}
