import Foundation

/// Finds open editor tabs by method, service, or proto file name.
public protocol SearchEditorTabsUseCaseProtocol: Sendable {
    /// Groups `tabs` by proto contract and keeps the tabs that match every word of `query`.
    /// - Parameters:
    ///   - tabs: Open tabs in tab order.
    ///   - query: Words separated by spaces, dots, or slashes. Matching ignores case. An empty query matches every tab.
    /// - Returns: Groups ordered by proto file name, then path, so closing a tab never reorders them;
    ///   tabs inside a group keep tab order.
    func execute(tabs: [EditorTab], query: String) -> [EditorTabGroup]
}
