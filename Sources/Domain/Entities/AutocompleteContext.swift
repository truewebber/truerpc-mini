/// Resolved JSON path and edit mode for autocomplete; raw editor state is not included.
public struct AutocompleteContext: Equatable, Sendable {
    public let resolvedPath: [String]
    public let mode: AutocompleteMode

    /// Keys already present in the current object scope (used to filter out filled fields).
    public let siblingKeys: Set<String>

    public init(resolvedPath: [String], mode: AutocompleteMode, siblingKeys: Set<String> = []) {
        self.resolvedPath = resolvedPath
        self.mode = mode
        self.siblingKeys = siblingKeys
    }
}
