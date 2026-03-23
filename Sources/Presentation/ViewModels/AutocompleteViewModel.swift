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

    // MARK: - Dependencies

    private let provider: AutocompleteProviderProtocol
    private let resolver: JsonPathResolver

    // MARK: - Private State

    private var inflightTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(provider: AutocompleteProviderProtocol, resolver: JsonPathResolver) {
        self.provider = provider
        self.resolver = resolver
    }

    // MARK: - Public Methods

    /// Called by `JSONTextEditor.Coordinator` on every keystroke.
    public func textDidChange(_ text: String, cursorOffset: Int, protoFile: ProtoFile) async {
        inflightTask?.cancel()

        let context = resolver.resolve(json: text, cursorOffset: cursorOffset)

        inflightTask = Task {
            let result = await provider.suggestions(for: context, in: protoFile)
            guard !Task.isCancelled else { return }

            self.suggestions = result
            self.selectedIndex = 0
            self.isVisible = !result.isEmpty
        }

        await inflightTask?.value
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
