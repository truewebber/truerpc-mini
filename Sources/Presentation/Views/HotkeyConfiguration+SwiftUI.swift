import SwiftUI

extension EnvironmentValues {
    /// Shortcuts that views apply to their controls; the app root injects the active configuration.
    @Entry var hotkeys: HotkeyConfiguration = .standard
}

extension HotkeyConfiguration {
    /// SwiftUI shortcut of `action`, or `nil` when the action has none.
    func keyboardShortcut(for action: HotkeyAction) -> KeyboardShortcut? {
        self[action]?.keyboardShortcut
    }
}

extension KeyCombination {
    var keyboardShortcut: KeyboardShortcut {
        KeyboardShortcut(key.keyEquivalent, modifiers: modifiers.eventModifiers)
    }
}

extension KeyCombination.Key {
    var keyEquivalent: KeyEquivalent {
        switch self {
        case let .character(character): KeyEquivalent(character)
        case .return: .return
        case .escape: .escape
        case .delete: .delete
        case .tab: .tab
        case .space: .space
        case .upArrow: .upArrow
        case .downArrow: .downArrow
        case .leftArrow: .leftArrow
        case .rightArrow: .rightArrow
        }
    }
}

extension KeyModifiers {
    /// Keeps only the modifiers a shortcut can use; Caps Lock, Fn and the numeric pad flag are dropped.
    init(_ eventModifiers: EventModifiers) {
        self = Self.mapping.reduce(into: []) { result, pair in
            if eventModifiers.contains(pair.event) {
                result.insert(pair.modifier)
            }
        }
    }

    var eventModifiers: EventModifiers {
        Self.mapping.reduce(into: []) { result, pair in
            if contains(pair.modifier) {
                result.insert(pair.event)
            }
        }
    }

    /// Modifier glyphs in the order macOS menus draw them, for example "⌥" or "⇧⌘".
    var symbols: String {
        Self.mapping.filter { contains($0.modifier) }.map(\.symbol).joined()
    }

    private static let mapping: [(modifier: KeyModifiers, event: EventModifiers, symbol: String)] = [
        (.control, .control, "⌃"),
        (.option, .option, "⌥"),
        (.shift, .shift, "⇧"),
        (.command, .command, "⌘"),
    ]
}
