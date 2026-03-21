/// Resolved JSON path and edit mode for autocomplete; raw editor state is not included.
public struct AutocompleteContext: Equatable, Sendable {
    public let resolvedPath: [String]
    public let mode: AutocompleteMode

    public init(resolvedPath: [String], mode: AutocompleteMode) {
        self.resolvedPath = resolvedPath
        self.mode = mode
    }
}
