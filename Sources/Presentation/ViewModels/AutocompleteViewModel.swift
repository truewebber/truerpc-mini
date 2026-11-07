import Foundation

/// Coordinates JSON autocomplete state for a single editor tab.
/// Responsible for data state only: suggestion list, visibility, and selection index.
/// Positioning of the popover is owned by `JSONTextEditor.Coordinator`.
@MainActor
public final class AutocompleteViewModel: ObservableObject {
    // MARK: - Published State

    @Published public var suggestions: [AutocompleteSuggestion] = []
    @Published public var isVisible: Bool = false
    @Published public var selectedIndex: Int = 0
    /// Type name for the empty value at the caret. `nil` hides the placeholder.
    @Published public var valueTypeHint: JsonValueTypeHint?

    // MARK: - Dependencies

    private let provider: AutocompleteProviderProtocol
    private let resolver: any JsonPathResolverProtocol
    private let methodInputType: String

    // MARK: - Handlers

    /// Called when the user commits the `fillDefaults` suggestion (keyboard or click).
    /// Wired by `EditorTabViewModel` to `resetToPreset()`.
    public var fillDefaultsHandler: (@MainActor @Sendable () async -> Void)?

    // MARK: - Private State

    private var inflightTask: Task<Void, Never>?

    /// Monotonic counter to discard results from superseded provider calls.
    private var updateVersion: UInt64 = 0

    /// Separate from `updateVersion` so a type-name refresh does not drop the suggestion list.
    private var hintVersion: UInt64 = 0

    // MARK: - Initialization

    public init(
        provider: AutocompleteProviderProtocol,
        resolver: any JsonPathResolverProtocol,
        methodInputType: String)
    {
        self.provider = provider
        self.resolver = resolver
        self.methodInputType = methodInputType
    }

    // MARK: - Public Methods

    /// Called by `JSONTextEditor.Coordinator` on every keystroke.
    public func textDidChange(_ text: String, cursorOffset: Int, protoFile: ProtoFile) async {
        inflightTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") else {
            suggestions = []
            isVisible = false
            selectedIndex = 0
            clearValueTypeHint()
            return
        }

        updateVersion &+= 1
        let expectedVersion = updateVersion

        let context = resolver.resolve(json: text, cursorOffset: cursorOffset)

        if context.isOutsideRootObject {
            suggestions = []
            isVisible = false
            selectedIndex = 0
            clearValueTypeHint()
            return
        }

        let allSiblings: Set<String>
        if context.mode == .key {
            let keysAfter = resolver.collectKeysAfterCursor(json: text, cursorOffset: cursorOffset)
            allSiblings = context.siblingKeys.union(keysAfter)
        } else {
            allSiblings = context.siblingKeys
        }

        let showHint = JsonValueTypeHintPlacement.shouldShow(
            context: context,
            text: text,
            cursorUTF16: cursorOffset)
        hintVersion &+= 1
        let expectedHintVersion = hintVersion

        inflightTask = Task {
            let result = await provider.suggestions(
                for: context,
                rootMessageType: methodInputType,
                in: protoFile)
            let hint = showHint
                ? await provider.valueTypeHint(
                    for: context,
                    rootMessageType: methodInputType,
                    in: protoFile)
                : nil

            guard expectedVersion == self.updateVersion else { return }

            let isRootLevel = context.resolvedPath.isEmpty
            // fillDefaults is only meaningful at root level when no fields have been filled yet.
            // At any nested path (or once any sibling key exists), it must be hidden.
            var filtered: [AutocompleteSuggestion] = if context.mode == .key {
                result.filter {
                    if $0.kind == .fillDefaults {
                        return isRootLevel && allSiblings.isEmpty
                    }
                    return !allSiblings.contains($0.name)
                }
            } else {
                result
            }

            // Filter by partial key prefix when the user has already started typing.
            // fillDefaults is never relevant while the user is actively typing a key name.
            // wktDefault is always kept — its display name doesn't match typed RFC 3339 / duration text.
            let partialKey = context.partialKey
            if !partialKey.isEmpty {
                let lower = partialKey.lowercased()
                filtered = filtered.filter {
                    $0.kind == .wktDefault || ($0.kind != .fillDefaults && $0.name.lowercased().hasPrefix(lower))
                }
            }

            self.suggestions = Self.sortSuggestions(filtered)
            self.selectedIndex = 0
            self.isVisible = !filtered.isEmpty
            if expectedHintVersion == self.hintVersion {
                self.valueTypeHint = hint
            }
        }

        await inflightTask?.value
    }

    /// Updates only the type-name placeholder. Used after a scalar insert and when the caret moves.
    public func refreshValueTypeHint(_ text: String, cursorOffset: Int, protoFile: ProtoFile) async {
        hintVersion &+= 1
        let expectedHintVersion = hintVersion

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") else {
            valueTypeHint = nil
            return
        }

        let context = resolver.resolve(json: text, cursorOffset: cursorOffset)
        guard !context.isOutsideRootObject,
              JsonValueTypeHintPlacement.shouldShow(
                  context: context,
                  text: text,
                  cursorUTF16: cursorOffset)
        else {
            valueTypeHint = nil
            return
        }

        let hint = await provider.valueTypeHint(
            for: context,
            rootMessageType: methodInputType,
            in: protoFile)
        guard expectedHintVersion == hintVersion else { return }

        valueTypeHint = hint
    }

    private func clearValueTypeHint() {
        hintVersion &+= 1
        valueTypeHint = nil
    }

    /// Sorts suggestions so `.fillDefaults` entries appear first.
    nonisolated static func sortSuggestions(_ suggestions: [AutocompleteSuggestion]) -> [AutocompleteSuggestion] {
        let fill = suggestions.filter { $0.kind == .fillDefaults }
        let rest = suggestions.filter { $0.kind != .fillDefaults }
        return fill + rest
    }

    /// Increments `selectedIndex`, wrapping to 0 after the last item.
    public func moveDown() {
        guard !suggestions.isEmpty else { return }

        selectedIndex = (selectedIndex + 1) % suggestions.count
    }

    /// Decrements `selectedIndex`, wrapping to the last item from 0.
    public func moveUp() {
        guard !suggestions.isEmpty else { return }

        selectedIndex = selectedIndex == 0 ? suggestions.count - 1 : selectedIndex - 1
    }

    /// Returns the currently selected suggestion; caller applies smart-insert.
    public func commitSelection() -> AutocompleteSuggestion? {
        guard !suggestions.isEmpty, selectedIndex < suggestions.count else { return nil }

        return suggestions[selectedIndex]
    }

    /// Hides the popover and clears all suggestion state.
    public func dismiss() {
        isVisible = false
        suggestions = []
        selectedIndex = 0
    }
}
