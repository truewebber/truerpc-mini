/// Keyboard shortcuts of the app commands plus the click modifier that opens a method in a new tab.
///
/// Platform keys are not listed: Return and Escape in dialogs, arrow keys in lists, and text editing
/// keys follow macOS conventions and the user's system key bindings.
public struct HotkeyConfiguration: Equatable, Sendable {
    private var combinations: [HotkeyAction: KeyCombination]

    /// Modifiers held while clicking a sidebar method to open it in a new tab. Empty disables the gesture.
    public var openInNewTabModifiers: KeyModifiers

    /// - Parameter combination: Shortcut for each action; `nil` leaves the action without a shortcut.
    public init(openInNewTabModifiers: KeyModifiers, combination: (HotkeyAction) -> KeyCombination?) {
        self.openInNewTabModifiers = openInNewTabModifiers
        self.combinations = HotkeyAction.allCases.reduce(into: [:]) { result, action in
            result[action] = combination(action)
        }
    }

    /// Shortcut of `action`, or `nil` when the action has none.
    public subscript(action: HotkeyAction) -> KeyCombination? {
        get { combinations[action] }
        set { combinations[action] = newValue }
    }

    /// Whether a click with `pressed` modifiers held opens a method in a new tab. Extra modifiers are allowed.
    public func opensInNewTab(withPressed pressed: KeyModifiers) -> Bool {
        !openInNewTabModifiers.isEmpty && pressed.isSuperset(of: openInNewTabModifiers)
    }
}
