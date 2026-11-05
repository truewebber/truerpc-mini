import SwiftUI

/// Horizontal bar displaying editor tabs with selection and close actions.
struct TabBarView: View {
    @ObservedObject var tabManager: TabManagerViewModel

    var body: some View {
        if tabManager.tabs.isEmpty {
            EmptyView()
        } else {
            TabBarStrip(
                items: tabManager.tabs.map {
                    TabBarStripItem(
                        id: $0.editorTab.id,
                        title: "\($0.editorTab.serviceName).\($0.editorTab.methodName)")
                },
                selectedID: tabManager.selectedTabId,
                onSelect: { tabManager.selectTab(id: $0) },
                onClose: { tabManager.removeTab(id: $0) })
        }
    }
}

private struct TabBarStripItem: Identifiable {
    let id: UUID
    let title: String
}

private struct TabBarStrip: View {
    let items: [TabBarStripItem]
    let selectedID: UUID?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(items) { item in
                    TabBarItemView(
                        title: item.title,
                        isSelected: selectedID == item.id,
                        onSelect: { onSelect(item.id) },
                        onClose: { onClose(item.id) })
                }
            }
        }
        .frame(height: 36)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct TabBarItemView: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.monospaced())
                .lineLimit(1)
                .foregroundStyle(labelStyle)

            if isHovered || isSelected {
                Button(action: onClose) {
                    Label("Close", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .foregroundStyle(labelStyle)
                .help("Close")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { isHovered = $0 }
    }

    private var labelStyle: Color {
        isSelected ? Color(nsColor: .alternateSelectedControlTextColor) : Color.primary
    }
}

#if DEBUG
    #Preview("Single", traits: .fixedLayout(width: 780, height: 36)) {
        previewTabBar(titles: ["UserService.GetUser"])
    }

    #Preview("Many", traits: .fixedLayout(width: 780, height: 36)) {
        previewTabBar(titles: [
            "UserService.GetUser",
            "UserService.StreamUsers",
            "BillingService.CreateInvoice",
            "BillingService.ListInvoices",
            "AdminService.GetStatus",
        ])
    }

    #Preview("Long Content", traits: .fixedLayout(width: 780, height: 36)) {
        previewTabBar(titles: [
            "CustomerBillingAndSubscriptionAdminService.GetUserProfileWithVeryLongMethodNameForLayoutChecks",
            "UserService.GetUser",
        ])
    }

    #Preview("Dark", traits: .fixedLayout(width: 780, height: 36)) {
        previewTabBar(titles: [
            "UserService.GetUser",
            "UserService.StreamUsers",
            "BillingService.CreateInvoice",
        ])
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func previewTabBar(titles: [String], selectedIndex: Int = 0) -> some View {
        let items = titles.map { TabBarStripItem(id: UUID(), title: $0) }
        return TabBarStrip(
            items: items,
            selectedID: items[selectedIndex].id,
            onSelect: { _ in },
            onClose: { _ in })
    }
#endif
