import SwiftUI

/// Editor tab strip. Every tab has the same width and shows the method, its service, and the contract color,
/// so tabs never shift under the pointer. The trailing button opens a searchable list of all open tabs.
struct TabBarView: View {
    @ObservedObject var tabManager: TabManagerViewModel
    @ObservedObject var switcher: TabSwitcherViewModel
    /// Contract color slots keyed by proto file path.
    let contractColorSlots: [URL: Int]

    var body: some View {
        if !tabManager.tabs.isEmpty {
            TabBarStrip(
                items: tabManager.tabs.map {
                    TabBarStripItem(tab: $0.editorTab, colorSlot: contractColorSlots[$0.editorTab.protoFile.path])
                },
                selectedID: tabManager.selectedTabId,
                isSwitcherPresented: $switcher.isPresented,
                onAction: perform)
            {
                TabSwitcherView(viewModel: switcher, contractColorSlots: contractColorSlots)
            }
        }
    }

    private func perform(_ action: TabBarAction) {
        switch action {
        case let .select(id):
            tabManager.selectTab(id: id)
        case let .close(id):
            tabManager.removeTab(id: id)
        case let .closeOthers(id):
            tabManager.removeOtherTabs(keeping: id)
        case let .closeToTheRight(id):
            tabManager.removeTabsToTheRight(of: id)
        case let .closeContract(protoFilePath):
            tabManager.removeTabs(inProtoFileAt: protoFilePath)
        }
    }
}

private enum TabBarAction {
    case select(UUID)
    case close(UUID)
    case closeOthers(UUID)
    case closeToTheRight(UUID)
    case closeContract(URL)
}

private struct TabBarStripItem: Identifiable {
    let id: UUID
    let methodName: String
    let serviceName: String
    let protoFileName: String
    let protoFilePath: URL
    let colorSlot: Int?

    init(tab: EditorTab, colorSlot: Int?) {
        self.id = tab.id
        self.methodName = tab.methodName
        self.serviceName = tab.serviceName
        self.protoFileName = tab.protoFile.name
        self.protoFilePath = tab.protoFile.path
        self.colorSlot = colorSlot
    }

    var fullName: String {
        "\(protoFileName) › \(serviceName) › \(methodName)"
    }
}

private struct TabBarStrip<Switcher: View>: View {
    let items: [TabBarStripItem]
    let selectedID: UUID?
    @Binding var isSwitcherPresented: Bool
    let onAction: (TabBarAction) -> Void
    @ViewBuilder let switcher: () -> Switcher

    /// Two text lines plus vertical padding.
    private static var height: CGFloat {
        40
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            TabBarItemView(
                                item: item,
                                isSelected: item.id == selectedID,
                                showsTrailingSeparator: showsSeparator(after: index),
                                canCloseOthers: items.count > 1,
                                canCloseToTheRight: index < items.count - 1,
                                onAction: onAction)
                                .id(item.id)
                        }
                    }
                }
                .scrollIndicators(.never)
                .onAppear { scrollToSelection(proxy) }
                .onChange(of: selectedID) {
                    withAnimation { scrollToSelection(proxy) }
                }
            }

            Divider()

            showAllTabsButton
        }
        .frame(height: Self.height)
        .background(alignment: .bottom) { Divider() }
        .background(.fill.tertiary)
    }

    private var showAllTabsButton: some View {
        Button {
            isSwitcherPresented.toggle()
        } label: {
            Label {
                Text(items.count, format: .number)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "square.on.square")
            }
            .labelStyle(.titleAndIcon)
            .font(.callout)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal)
        .help("Show All Tabs")
        .accessibilityLabel("Show All Tabs")
        .accessibilityValue(Text("\(items.count) tabs"))
        .popover(isPresented: $isSwitcherPresented, arrowEdge: .bottom, content: switcher)
    }

    private func showsSeparator(after index: Int) -> Bool {
        let isSelected = items[index].id == selectedID
        let nextIsSelected = index + 1 < items.count && items[index + 1].id == selectedID
        return !isSelected && !nextIsSelected
    }

    private func scrollToSelection(_ proxy: ScrollViewProxy) {
        guard let selectedID else { return }

        proxy.scrollTo(selectedID)
    }
}

private struct TabBarItemView: View {
    let item: TabBarStripItem
    let isSelected: Bool
    let showsTrailingSeparator: Bool
    let canCloseOthers: Bool
    let canCloseToTheRight: Bool
    let onAction: (TabBarAction) -> Void
    @State private var isHovered: Bool

    /// Same for every tab, so long names truncate instead of pushing neighbors away.
    private static let width: CGFloat = 180
    /// Holds the contract icon or, while hovered, the close button — swapping them never moves the title.
    private static let leadingSlotSize: CGFloat = 16

    init(
        item: TabBarStripItem,
        isSelected: Bool,
        showsTrailingSeparator: Bool,
        canCloseOthers: Bool,
        canCloseToTheRight: Bool,
        isHovered: Bool = false,
        onAction: @escaping (TabBarAction) -> Void)
    {
        self.item = item
        self.isSelected = isSelected
        self.showsTrailingSeparator = showsTrailingSeparator
        self.canCloseOthers = canCloseOthers
        self.canCloseToTheRight = canCloseToTheRight
        self.onAction = onAction
        _isHovered = State(initialValue: isHovered)
    }

    var body: some View {
        HStack(spacing: 6) {
            leadingSlot

            VStack(alignment: .leading, spacing: 0) {
                Text(item.methodName)
                    .font(.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                Text(item.serviceName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background { background }
        .overlay(alignment: .trailing) {
            if showsTrailingSeparator {
                HStack { Divider() }
                    .padding(.vertical, 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onAction(.select(item.id)) }
        .onHover { isHovered = $0 }
        .help(item.fullName)
        .contextMenu { contextMenu }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.methodName), \(item.serviceName), \(item.protoFileName)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { onAction(.select(item.id)) }
        .accessibilityAction(named: "Close Tab") { onAction(.close(item.id)) }
    }

    private var leadingSlot: some View {
        ZStack {
            if isHovered {
                Button {
                    onAction(.close(item.id))
                } label: {
                    Label("Close Tab", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Close Tab")
            } else {
                ContractIcon(colorSlot: item.colorSlot)
            }
        }
        .font(.callout)
        .frame(width: Self.leadingSlotSize, height: Self.leadingSlotSize)
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            Rectangle().fill(.background)
        } else if isHovered {
            Rectangle().fill(.fill.quaternary)
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Close Tab") { onAction(.close(item.id)) }
        Button("Close Other Tabs") { onAction(.closeOthers(item.id)) }
            .disabled(!canCloseOthers)
        Button("Close Tabs to the Right") { onAction(.closeToTheRight(item.id)) }
            .disabled(!canCloseToTheRight)
        Divider()
        Button("Close Tabs from “\(item.protoFileName)”") { onAction(.closeContract(item.protoFilePath)) }
    }
}

#if DEBUG
    #Preview("Single", traits: .fixedLayout(width: 780, height: 40)) {
        previewTabBar(tabs: Array(PreviewContracts.mixedTabs.prefix(1)))
    }

    #Preview("Many", traits: .fixedLayout(width: 780, height: 40)) {
        previewTabBar(tabs: Array(PreviewContracts.mixedTabs.prefix(4)), selectedIndex: 1)
    }

    #Preview("Contracts", traits: .fixedLayout(width: 1100, height: 40)) {
        previewTabBar(tabs: PreviewContracts.mixedTabs, selectedIndex: 2)
    }

    #Preview("Long Content", traits: .fixedLayout(width: 780, height: 40)) {
        previewTabBar(tabs: PreviewContracts.longNameTabs, slots: PreviewContracts.longNameColorSlots)
    }

    #Preview("Hover", traits: .sizeThatFitsLayout) {
        let tabs = PreviewContracts.mixedTabs
        HStack(spacing: 0) {
            ForEach(0 ..< 3, id: \.self) { index in
                TabBarItemView(
                    item: TabBarStripItem(tab: tabs[index], colorSlot: PreviewContracts.colorSlots[
                        tabs[index].protoFile.path,
                    ]),
                    isSelected: index == 0,
                    showsTrailingSeparator: index == 1,
                    canCloseOthers: true,
                    canCloseToTheRight: true,
                    isHovered: index == 1,
                    onAction: { _ in })
            }
        }
        .frame(height: 40)
        .background(.fill.tertiary)
    }

    #Preview("Overflow", traits: .fixedLayout(width: 780, height: 40)) {
        previewTabBar(tabs: PreviewContracts.manyTabs, selectedIndex: 40)
    }

    #Preview("Dark", traits: .fixedLayout(width: 780, height: 40)) {
        previewTabBar(tabs: PreviewContracts.mixedTabs, selectedIndex: 1)
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func previewTabBar(
        tabs: [EditorTab],
        slots: [URL: Int] = PreviewContracts.colorSlots,
        selectedIndex: Int = 0)
        -> some View
    {
        TabBarStrip(
            items: tabs.map { TabBarStripItem(tab: $0, colorSlot: slots[$0.protoFile.path]) },
            selectedID: tabs[selectedIndex].id,
            isSwitcherPresented: .constant(false),
            onAction: { _ in },
            switcher: { EmptyView() })
            .background(.background)
    }
#endif
