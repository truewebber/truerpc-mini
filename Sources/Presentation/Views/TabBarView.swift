import SwiftUI

/// Horizontal bar displaying editor tabs with selection and close actions
struct TabBarView: View {
    @ObservedObject var tabManager: TabManagerViewModel

    var body: some View {
        if tabManager.tabs.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabManager.tabs, id: \.editorTab.id) { tabVM in
                        TabBarItemView(
                            tabViewModel: tabVM,
                            isSelected: tabManager.selectedTabId == tabVM.editorTab.id,
                            onSelect: { tabManager.selectTab(id: tabVM.editorTab.id) },
                            onClose: { tabManager.removeTab(id: tabVM.editorTab.id) })
                    }
                }
            }
            .frame(height: 36)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

private struct TabBarItemView: View {
    let tabViewModel: EditorTabViewModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text("\(tabViewModel.editorTab.serviceName).\(tabViewModel.editorTab.methodName)")
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)

            if isHovered || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { isHovered = $0 }
    }
}
