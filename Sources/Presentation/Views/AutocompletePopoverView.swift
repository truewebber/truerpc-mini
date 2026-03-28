import SwiftUI

/// Pure SwiftUI view that renders the autocomplete suggestion list.
/// Hosted inside an `NSPopover` via `NSHostingController` by `JSONTextEditor.Coordinator`.
/// Positioning is entirely AppKit's responsibility — this view owns no anchor geometry.
public struct AutocompletePopoverView: View {
    @ObservedObject public var viewModel: AutocompleteViewModel

    /// Called when the user selects a suggestion (tap or keyboard Enter/Tab).
    /// Wired by `JSONTextEditor.Coordinator` to apply smart-insert or trigger fillDefaults.
    var onRowTapped: ((AutocompleteSuggestion) -> Void)?

    /// Called when the user presses Escape inside the popover.
    /// Wired by `JSONTextEditor.Coordinator` to dismiss and close the popover.
    var onEscape: (() -> Void)?

    private let maxHeight: CGFloat = 240

    public init(
        viewModel: AutocompleteViewModel,
        onRowTapped: ((AutocompleteSuggestion) -> Void)? = nil,
        onEscape: (() -> Void)? = nil)
    {
        self.viewModel = viewModel
        self.onRowTapped = onRowTapped
        self.onEscape = onEscape
    }

    private static let rowHeight: CGFloat = 28

    private var contentHeight: CGFloat {
        min(CGFloat(viewModel.suggestions.count) * Self.rowHeight, maxHeight)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isSelected: index == viewModel.selectedIndex,
                            index: index)
                            .id(index)
                            .onTapGesture {
                                onRowTapped?(suggestion)
                            }
                    }
                }
            }
            .frame(height: contentHeight)
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
        .accessibilityIdentifier("autocomplete_popover")
    }
}

// MARK: - SuggestionRow

private struct SuggestionRow: View {
    let suggestion: AutocompleteSuggestion
    let isSelected: Bool
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            kindIcon
                .frame(width: 16, height: 16)

            Text(suggestion.name)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("suggestion_name_\(index)")

            Text(suggestion.typeHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityIdentifier("suggestion_type_\(index)")
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .opacity(suggestion.oneOfGroup != nil ? 0.7 : 1.0)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suggestion_row_\(index)")
    }

    @ViewBuilder
    private var kindIcon: some View {
        switch suggestion.kind {
        case .message:
            Image(systemName: "curlybraces")
                .foregroundStyle(Color.purple)

        case .repeated:
            Image(systemName: "square.stack")
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
                resolver: JsonPathResolver(),
                methodInputType: ".preview.PreviewMessage")
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
            rootMessageType _: String,
            in _: ProtoFile)
            -> [AutocompleteSuggestion]
        {
            []
        }
    }
#endif
