import Foundation

/// Open editor tabs that the tab switcher lists, selects, and closes.
@MainActor
public protocol TabSwitcherDataSource: AnyObject {
    /// Open tabs in tab-bar order.
    var editorTabs: [EditorTab] { get }
    var selectedTabId: UUID? { get }
    func selectTab(id: UUID?)
    func removeTab(id: UUID)
}
