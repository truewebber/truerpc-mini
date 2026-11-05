/// App commands that can be bound to a keyboard shortcut in `HotkeyConfiguration`.
public enum HotkeyAction: CaseIterable, Hashable, Sendable {
    /// Closes the selected editor tab. Also closes the window when no tab is open.
    case closeTab
    /// Closes the window while an editor tab is open.
    case closeWindow
    case showPreviousTab
    case showNextTab
    /// Toggles the searchable list of all open tabs.
    case showAllTabs
    /// Sends the request of the selected editor tab.
    case executeRequest
}
