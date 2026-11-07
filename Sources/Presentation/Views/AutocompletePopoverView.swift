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

    public init(
        viewModel: AutocompleteViewModel,
        onRowTapped: ((AutocompleteSuggestion) -> Void)? = nil,
        onEscape: (() -> Void)? = nil)
    {
        self.viewModel = viewModel
        self.onRowTapped = onRowTapped
        self.onEscape = onEscape
    }

    public var body: some View {
        FittedPopover(
            selection: viewModel.selectedIndex,
            minWidth: AutocompletePopoverSize.minWidth,
            maxWidth: AutocompletePopoverSize.maxWidth,
            maxHeight: AutocompletePopoverSize.maxHeight)
        {
            VStack(spacing: AutocompletePopoverSize.rowSpacing) {
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
            .padding(AutocompletePopoverSize.outerInset)
        }
        .accessibilityIdentifier("autocomplete_popover")
    }
}

/// Limits for the suggestion panel. Height follows the row count up to `maxHeight`; width hugs the text.
enum AutocompletePopoverSize {
    static let minWidth: CGFloat = 240
    static let maxWidth: CGFloat = 380
    static let maxHeight: CGFloat = 320
    static let outerInset: CGFloat = 6
    static let rowSpacing: CGFloat = 2

    static func fitted(
        _ content: CGSize,
        minWidth: CGFloat = Self.minWidth,
        maxWidth: CGFloat = Self.maxWidth,
        maxHeight: CGFloat = Self.maxHeight)
        -> CGSize
    {
        CGSize(
            width: min(max(content.width, minWidth), maxWidth),
            height: min(max(content.height, 0), maxHeight))
    }
}

/// Sizes a popover to its rows, then scrolls once the list is taller than `maxHeight`.
private struct FittedPopover<Content: View>: View {
    var selection: Int
    var minWidth: CGFloat
    var maxWidth: CGFloat
    var maxHeight: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        FittedPopoverLayout(minWidth: minWidth, maxWidth: maxWidth, maxHeight: maxHeight) {
            ScrollView(.vertical) {
                ScrollViewReader { proxy in
                    content()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: selection) { _, newValue in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                proxy.scrollTo(newValue, anchor: .center)
                            }
                        }
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            content()
                .fixedSize(horizontal: true, vertical: true)
                .hidden()
                .accessibilityHidden(true)
        }
    }
}

private struct FittedPopoverLayout: Layout {
    var minWidth: CGFloat
    var maxWidth: CGFloat
    var maxHeight: CGFloat

    func sizeThatFits(proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard subviews.count > 1 else { return .zero }

        let natural = subviews[1].sizeThatFits(.unspecified)
        return AutocompletePopoverSize.fitted(
            natural,
            minWidth: minWidth,
            maxWidth: maxWidth,
            maxHeight: maxHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard let scrollView = subviews.first else { return }

        scrollView.place(
            at: bounds.origin,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
        if subviews.count > 1 {
            subviews[1].place(
                at: bounds.origin,
                proposal: ProposedViewSize(width: 0, height: 0))
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: AutocompleteSuggestion
    let isSelected: Bool
    let index: Int

    var body: some View {
        HStack(alignment: .center) {
            kindIcon
                .foregroundStyle(isSelected ? rowTextStyle : kindColor)
                .frame(width: 16, height: 16)

            Text(suggestion.name)
                .font(.body.monospaced())
                .lineLimit(1)
                .layoutPriority(1)
                .foregroundStyle(rowTextStyle)
                .accessibilityIdentifier("suggestion_name_\(index)")

            Spacer(minLength: 12)

            Text(suggestion.typeHint)
                .font(.caption)
                .foregroundStyle(isSelected ? rowTextStyle : AnyShapeStyle(.secondary))
                .lineLimit(1)
                .accessibilityIdentifier("suggestion_type_\(index)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .selectedContentBackgroundColor))
            }
        }
        .opacity(suggestion.oneOfGroup != nil ? 0.7 : 1.0)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suggestion_row_\(index)")
    }

    private var rowTextStyle: AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(Color(nsColor: .alternateSelectedControlTextColor))
            : AnyShapeStyle(.primary)
    }

    private var kindColor: AnyShapeStyle {
        switch suggestion.kind {
        case .message, .fillDefaults:
            AnyShapeStyle(.blue)
        case .string:
            AnyShapeStyle(.brown)
        case .number:
            AnyShapeStyle(.teal)
        case .bool, .boolLiteral:
            AnyShapeStyle(.purple)
        case .repeated, .enumField, .enum, .wktString, .wktDefault:
            AnyShapeStyle(.secondary)
        }
    }

    private var kindIcon: Image {
        switch suggestion.kind {
        case .message:
            Image(systemName: "curlybraces")
        case .repeated:
            Image(systemName: "square.stack")
        case .string:
            Image(systemName: "text.quote")
        case .number:
            Image(systemName: "number.circle")
        case .bool, .boolLiteral:
            Image(systemName: "checkmark.circle")
        case .enumField:
            Image(systemName: "list.bullet")
        case .enum:
            Image(systemName: "checklist")
        case .wktString:
            Image(systemName: "clock")
        case .wktDefault:
            Image(systemName: "clock.badge.checkmark")
        case .fillDefaults:
            Image(systemName: "sparkles")
        }
    }
}

#if DEBUG
    #Preview("Single", traits: .sizeThatFitsLayout) {
        AutocompletePopoverView(viewModel: previewAutocompleteViewModel(
            suggestions: [
                AutocompleteSuggestion(name: "now", typeHint: "Timestamp RFC 3339", kind: .wktDefault),
            ],
            selectedIndex: 0))
    }

    #Preview("Suggestions", traits: .sizeThatFitsLayout) {
        AutocompletePopoverView(viewModel: previewAutocompleteViewModel(
            suggestions: previewSuggestions,
            selectedIndex: -1))
    }

    #Preview("Selected", traits: .sizeThatFitsLayout) {
        AutocompletePopoverView(viewModel: previewAutocompleteViewModel(
            suggestions: previewSuggestions,
            selectedIndex: 2))
    }

    #Preview("One Of", traits: .sizeThatFitsLayout) {
        AutocompletePopoverView(viewModel: previewAutocompleteViewModel(
            suggestions: [
                AutocompleteSuggestion(
                    name: "email",
                    typeHint: "string",
                    kind: .string,
                    oneOfGroup: "contact"),
                AutocompleteSuggestion(
                    name: "phone",
                    typeHint: "string",
                    kind: .string,
                    oneOfGroup: "contact"),
            ],
            selectedIndex: 0))
    }

    #Preview("Empty", traits: .sizeThatFitsLayout) {
        AutocompletePopoverView(viewModel: previewAutocompleteViewModel(suggestions: []))
    }

    #Preview("Dark", traits: .sizeThatFitsLayout) {
        AutocompletePopoverView(viewModel: previewAutocompleteViewModel(
            suggestions: previewSuggestions,
            selectedIndex: 1))
            .preferredColorScheme(.dark)
    }

    private let previewSuggestions: [AutocompleteSuggestion] = [
        AutocompleteSuggestion(name: "(fill defaults)", typeHint: "all fields", kind: .fillDefaults),
        AutocompleteSuggestion(name: "firstName", typeHint: "string", kind: .string),
        AutocompleteSuggestion(name: "lastName", typeHint: "string", kind: .string),
        AutocompleteSuggestion(name: "age", typeHint: "int32", kind: .number),
        AutocompleteSuggestion(name: "active", typeHint: "bool", kind: .bool),
        AutocompleteSuggestion(name: "address", typeHint: "Address", kind: .message),
        AutocompleteSuggestion(name: "tags", typeHint: "string", kind: .repeated),
        AutocompleteSuggestion(name: "status", typeHint: "Status", kind: .enumField),
        AutocompleteSuggestion(name: "ACTIVE", typeHint: "Status", kind: .enum),
        AutocompleteSuggestion(name: "createdAt", typeHint: "Timestamp", kind: .wktString),
        AutocompleteSuggestion(name: "insert default value", typeHint: "Timestamp", kind: .wktDefault),
    ]

    @MainActor
    private func previewAutocompleteViewModel(
        suggestions: [AutocompleteSuggestion],
        selectedIndex: Int = 0)
        -> AutocompleteViewModel
    {
        let viewModel = AutocompleteViewModel(
            provider: PreviewAutocompleteProvider(),
            resolver: JsonPathResolver(),
            methodInputType: ".preview.PreviewMessage")
        viewModel.suggestions = suggestions
        viewModel.selectedIndex = selectedIndex
        viewModel.isVisible = !suggestions.isEmpty
        return viewModel
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
