public extension HotkeyConfiguration {
    /// Built-in shortcuts. Remap a command by changing its entry; return `nil` to leave it without a shortcut.
    static let standard = HotkeyConfiguration(openInNewTabModifiers: .option) { action in
        switch action {
        case .closeTab: KeyCombination("w")
        case .closeWindow: KeyCombination("w", modifiers: [.command, .shift])
        case .showPreviousTab: KeyCombination("[", modifiers: [.command, .shift])
        case .showNextTab: KeyCombination("]", modifiers: [.command, .shift])
        case .showAllTabs: KeyCombination("\\", modifiers: [.command, .shift])
        case .executeRequest: KeyCombination(.return)
        }
    }
}
