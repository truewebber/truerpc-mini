import SwiftUI

/// Searchable list of every open tab, grouped by contract. Arrow keys move the highlight, Return opens the
/// highlighted tab, a click opens any tab.
struct TabSwitcherView: View {
    @ObservedObject var viewModel: TabSwitcherViewModel
    /// Contract color slots keyed by proto file path.
    let contractColorSlots: [URL: Int]
    @FocusState private var isSearchFocused: Bool

    private static let size = CGSize(width: 400, height: 440)

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding()

            Divider()

            content
                .frame(maxHeight: .infinity)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .onAppear { isSearchFocused = true }
    }

    private var searchField: some View {
        TextField("Search Tabs", text: $viewModel.query, prompt: Text("Method, service, or file"))
            .textFieldStyle(.roundedBorder)
            .focused($isSearchFocused)
            .onSubmit(viewModel.activateHighlightedTab)
            .onKeyPress(.upArrow) {
                viewModel.moveHighlight(by: -1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                viewModel.moveHighlight(by: 1)
                return .handled
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.totalTabCount == 0 {
            ContentUnavailableView {
                Label("No Open Tabs", systemImage: "square.on.square")
            } description: {
                Text("Select a method in the sidebar to open a tab.")
            }
        } else if viewModel.groups.isEmpty {
            ContentUnavailableView.search(text: viewModel.query)
        } else {
            tabList
        }
    }

    private var tabList: some View {
        ScrollViewReader { proxy in
            List(selection: highlightBinding) {
                ForEach(viewModel.groups) { group in
                    Section {
                        ForEach(group.tabs) { tab in
                            TabSwitcherRow(
                                tab: tab,
                                isCurrent: tab.id == viewModel.selectedTabID,
                                onClose: { viewModel.closeTab(id: tab.id) })
                                .tag(tab.id)
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.activate(tabID: tab.id) }
                        }
                    } header: {
                        TabSwitcherSectionHeader(
                            protoFileName: group.protoFileName,
                            tabCount: group.tabs.count,
                            colorSlot: contractColorSlots[group.protoFilePath])
                    }
                }
            }
            .listStyle(.inset)
            .task { scrollToHighlight(proxy, anchor: .center) }
            .onChange(of: viewModel.highlightedTabID) { scrollToHighlight(proxy) }
        }
    }

    private var highlightBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.highlightedTabID },
            set: { id in
                if let id {
                    viewModel.highlight(tabID: id)
                }
            })
    }

    private func scrollToHighlight(_ proxy: ScrollViewProxy, anchor: UnitPoint? = nil) {
        guard let id = viewModel.highlightedTabID else { return }

        proxy.scrollTo(id, anchor: anchor)
    }
}

private struct TabSwitcherSectionHeader: View {
    let protoFileName: String
    let tabCount: Int
    let colorSlot: Int?

    var body: some View {
        HStack {
            Label {
                Text(protoFileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                ContractIcon(colorSlot: colorSlot)
            }

            Spacer()

            Text(tabCount, format: .number)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(tabCount) tabs")
        }
    }
}

private struct TabSwitcherRow: View {
    let tab: EditorTab
    let isCurrent: Bool
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(tab.methodName)
                    .fontWeight(isCurrent ? .semibold : .regular)
                Text(tab.serviceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .truncationMode(.middle)

            Spacer(minLength: 0)

            if isCurrent {
                Text("Current")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: onClose) {
                Label("Close Tab", systemImage: "xmark.circle.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Close Tab")
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(isHovered)
            .accessibilityHidden(true)
        }
        .onHover { isHovered = $0 }
        .help("\(tab.protoFile.name) › \(tab.serviceName) › \(tab.methodName)")
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityAction(named: "Close Tab", onClose)
    }
}

#if DEBUG
    #Preview("Default", traits: .sizeThatFitsLayout) {
        previewSwitcher(tabs: PreviewContracts.mixedTabs, selectedIndex: 2)
    }

    #Preview("Filtered", traits: .sizeThatFitsLayout) {
        previewSwitcher(tabs: PreviewContracts.mixedTabs, selectedIndex: 2, query: "user")
    }

    #Preview("No Results", traits: .sizeThatFitsLayout) {
        previewSwitcher(tabs: PreviewContracts.mixedTabs, selectedIndex: 2, query: "payments")
    }

    #Preview("Empty", traits: .sizeThatFitsLayout) {
        previewSwitcher(tabs: [], selectedIndex: nil)
    }

    #Preview("Long Content", traits: .sizeThatFitsLayout) {
        previewSwitcher(
            tabs: PreviewContracts.longNameTabs,
            selectedIndex: 0,
            slots: PreviewContracts.longNameColorSlots)
    }

    #Preview("Dark", traits: .sizeThatFitsLayout) {
        previewSwitcher(tabs: PreviewContracts.mixedTabs, selectedIndex: 2)
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func previewSwitcher(
        tabs: [EditorTab],
        selectedIndex: Int?,
        query: String = "",
        slots: [URL: Int] = PreviewContracts.colorSlots)
        -> some View
    {
        let source = PreviewTabSource(tabs: tabs, selectedTabId: selectedIndex.map { tabs[$0].id })
        let viewModel = TabSwitcherViewModel(dataSource: source, searchEditorTabsUseCase: SearchEditorTabsUseCase())
        viewModel.present()
        viewModel.query = query
        return TabSwitcherView(viewModel: viewModel, contractColorSlots: slots)
    }

    @MainActor
    private final class PreviewTabSource: TabSwitcherDataSource {
        private(set) var editorTabs: [EditorTab]
        private(set) var selectedTabId: UUID?

        init(tabs: [EditorTab], selectedTabId: UUID?) {
            self.editorTabs = tabs
            self.selectedTabId = selectedTabId
        }

        func selectTab(id: UUID?) {
            selectedTabId = id
        }

        func removeTab(id: UUID) {
            editorTabs.removeAll { $0.id == id }
        }
    }
#endif
