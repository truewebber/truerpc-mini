import Combine
import Foundation

/// State of the "Show All Tabs" switcher: searches open tabs, moves a keyboard highlight, selects and closes tabs.
@MainActor
public final class TabSwitcherViewModel: ObservableObject {
    @Published public var isPresented = false {
        didSet {
            if isPresented, !oldValue {
                prepareForPresentation()
            }
        }
    }

    @Published public var query = "" {
        didSet {
            guard query != oldValue else { return }

            refreshGroups()
            highlightedTabID = visibleTabIDs.first
        }
    }

    /// Matching tabs grouped by proto contract.
    @Published public private(set) var groups: [EditorTabGroup] = []
    /// The row that Return activates.
    @Published public private(set) var highlightedTabID: UUID?

    public var selectedTabID: UUID? {
        dataSource.selectedTabId
    }

    public var totalTabCount: Int {
        dataSource.editorTabs.count
    }

    private let dataSource: TabSwitcherDataSource
    private let searchEditorTabsUseCase: SearchEditorTabsUseCaseProtocol

    public init(dataSource: TabSwitcherDataSource, searchEditorTabsUseCase: SearchEditorTabsUseCaseProtocol) {
        self.dataSource = dataSource
        self.searchEditorTabsUseCase = searchEditorTabsUseCase
    }

    public func present() {
        isPresented = true
    }

    public func dismiss() {
        isPresented = false
    }

    public func togglePresentation() {
        isPresented.toggle()
    }

    public func highlight(tabID: UUID) {
        highlightedTabID = tabID
    }

    /// Moves the highlight by `offset` rows across all groups, stopping at the first and last row.
    public func moveHighlight(by offset: Int) {
        let ids = visibleTabIDs
        guard !ids.isEmpty else { return }

        let currentIndex = highlightedTabID.flatMap { ids.firstIndex(of: $0) }
        let targetIndex = currentIndex.map { $0 + offset } ?? (offset > 0 ? 0 : ids.count - 1)
        highlightedTabID = ids[min(max(targetIndex, 0), ids.count - 1)]
    }

    public func activateHighlightedTab() {
        guard let highlightedTabID else { return }

        activate(tabID: highlightedTabID)
    }

    public func activate(tabID: UUID) {
        dataSource.selectTab(id: tabID)
        dismiss()
    }

    /// Closes the tab and keeps the switcher open. A closed highlighted row passes the highlight to the row below.
    public func closeTab(id: UUID) {
        let highlightedIndex = highlightedTabID == id ? visibleTabIDs.firstIndex(of: id) : nil
        dataSource.removeTab(id: id)
        refreshGroups()

        guard let highlightedIndex else { return }

        let ids = visibleTabIDs
        highlightedTabID = ids.isEmpty ? nil : ids[min(highlightedIndex, ids.count - 1)]
    }

    private var visibleTabIDs: [UUID] {
        groups.flatMap { $0.tabs.map(\.id) }
    }

    private func prepareForPresentation() {
        query = ""
        refreshGroups()
        let ids = visibleTabIDs
        highlightedTabID = dataSource.selectedTabId.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first
    }

    private func refreshGroups() {
        groups = searchEditorTabsUseCase.execute(tabs: dataSource.editorTabs, query: query)
    }
}
