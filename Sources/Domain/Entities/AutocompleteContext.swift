/// Resolved JSON path and edit mode for autocomplete; raw editor state is not included.
public struct AutocompleteContext: Equatable, Sendable {
    public let resolvedPath: [String]
    public let mode: AutocompleteMode

    /// Keys already present in the current object scope (used to filter out filled fields).
    public let siblingKeys: Set<String>

    /// True when the cursor is positioned after the root `{}` has been fully closed.
    /// In this case no autocomplete suggestions should be shown.
    public let isOutsideRootObject: Bool

    /// The partial text the user is currently typing at the cursor position.
    /// Non-empty when cursor is inside an unclosed key string (e.g. `"dfdf`) or
    /// after bare (unquoted) text in key position (e.g. `{dfdf`), or when cursor
    /// is inside an unclosed value string in enum-value mode (e.g. `"ACT`).
    /// Used to prefix-filter the suggestion list.
    public let partialKey: String

    /// The field key whose value is currently being edited.
    /// Set when `mode == .enumValue` to enable enum-value suggestion lookup.
    /// `nil` for `.key` and `.arrayElement` modes.
    public let currentFieldKey: String?

    public init(
        resolvedPath: [String],
        mode: AutocompleteMode,
        siblingKeys: Set<String> = [],
        isOutsideRootObject: Bool = false,
        partialKey: String = "",
        currentFieldKey: String? = nil)
    {
        self.resolvedPath = resolvedPath
        self.mode = mode
        self.siblingKeys = siblingKeys
        self.isOutsideRootObject = isOutsideRootObject
        self.partialKey = partialKey
        self.currentFieldKey = currentFieldKey
    }
}
