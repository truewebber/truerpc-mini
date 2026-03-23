import SwiftUI

/// Pure SwiftUI view that renders the autocomplete suggestion list.
/// Hosted inside an `NSPopover` via `NSHostingController` by `JSONTextEditor.Coordinator`.
/// Positioning is entirely AppKit's responsibility — this view owns no anchor geometry.
public struct AutocompletePopoverView: View {
    @ObservedObject public var viewModel: AutocompleteViewModel

    private let maxHeight: CGFloat = 240

    public init(viewModel: AutocompleteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(sortedSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isSelected: index == viewModel.selectedIndex)
                            .id(index)
                    }
                }
            }
            .frame(maxHeight: maxHeight)
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator, lineWidth: 1))
        .frame(width: 320)
        .onKeyPress(.upArrow) {
            viewModel.moveUp()
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.moveDown()
            return .handled
        }
        .onKeyPress(.return) {
            _ = viewModel.commitSelection()
            return .handled
        }
        .onKeyPress(.tab) {
            _ = viewModel.commitSelection()
            return .handled
        }
        .onKeyPress(.escape) {
            viewModel.dismiss()
            return .handled
        }
    }

    // MARK: - Internal Helpers

    /// Sorts suggestions so `.fillDefaults` entries appear first.
    /// Internal access level allows unit testing without snapshot infrastructure.
    static func sortSuggestions(_ suggestions: [AutocompleteSuggestion]) -> [AutocompleteSuggestion] {
        let fillDefaultsItems = suggestions.filter { $0.kind == .fillDefaults }
        let others = suggestions.filter { $0.kind != .fillDefaults }
        return fillDefaultsItems + others
    }

    var sortedSuggestions: [AutocompleteSuggestion] {
        Self.sortSuggestions(viewModel.suggestions)
    }
}

// MARK: - SuggestionRow

private struct SuggestionRow: View {
    let suggestion: AutocompleteSuggestion
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            kindIcon
                .frame(width: 16, height: 16)

            Text(suggestion.name)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(suggestion.typeHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .opacity(suggestion.oneOfGroup != nil ? 0.7 : 1.0)
    }

    @ViewBuilder
    private var kindIcon: some View {
        switch suggestion.kind {
        case .message:
            Image(systemName: "curlybraces")
                .foregroundStyle(Color.purple)

        case .repeated:
            Image(systemName: "brackets")
                .foregroundStyle(Color.orange)

        case .string:
            Image(systemName: "text.quote")
                .foregroundStyle(Color.green)

        case .number:
            Image(systemName: "number.circle")
                .foregroundStyle(Color.blue)

        case .bool:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(Color.teal)

        case .enum:
            Image(systemName: "list.bullet")
                .foregroundStyle(Color.yellow)

        case .fillDefaults:
            Image(systemName: "sparkles")
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing))
        }
    }
}

#if DEBUG
    struct AutocompletePopoverView_Previews: PreviewProvider {
        static var previews: some View {
            AutocompletePopoverView(viewModel: previewViewModel)
                .padding()
                .previewDisplayName("Autocomplete Popover")
        }

        @MainActor
        private static var previewViewModel: AutocompleteViewModel {
            let vm = AutocompleteViewModel(
                provider: PreviewAutocompleteProvider(),
                resolver: JsonPathResolver())
            vm.suggestions = [
                AutocompleteSuggestion(name: "(fill defaults)", typeHint: "all fields", kind: .fillDefaults),
                AutocompleteSuggestion(name: "firstName", typeHint: "string", kind: .string),
                AutocompleteSuggestion(name: "lastName", typeHint: "string", kind: .string),
                AutocompleteSuggestion(name: "age", typeHint: "int32", kind: .number),
                AutocompleteSuggestion(name: "active", typeHint: "bool", kind: .bool),
                AutocompleteSuggestion(name: "address", typeHint: "Address", kind: .message),
                AutocompleteSuggestion(name: "tags", typeHint: "string", kind: .repeated),
                AutocompleteSuggestion(name: "status", typeHint: "Status", kind: .enum),
            ]
            vm.selectedIndex = 1
            vm.isVisible = true
            return vm
        }
    }

    private struct PreviewAutocompleteProvider: AutocompleteProviderProtocol {
        func suggestions(
            for _: AutocompleteContext,
            in _: ProtoFile)
            -> [AutocompleteSuggestion]
        {
            []
        }
    }
#endif
