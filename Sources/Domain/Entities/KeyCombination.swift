/// A key pressed together with modifier keys, independent of any UI framework.
public struct KeyCombination: Hashable, Sendable {
    public let key: Key
    public let modifiers: KeyModifiers

    public init(_ key: Key, modifiers: KeyModifiers = .command) {
        self.key = key
        self.modifiers = modifiers
    }

    public init(_ character: Character, modifiers: KeyModifiers = .command) {
        self.init(.character(character), modifiers: modifiers)
    }
}

public extension KeyCombination {
    /// The non-modifier key of a combination.
    enum Key: Hashable, Sendable {
        /// A printable key, written in lowercase: an uppercase letter implies Shift in macOS menus.
        case character(Character)
        case `return`
        case escape
        case delete
        case tab
        case space
        case upArrow
        case downArrow
        case leftArrow
        case rightArrow
    }
}

/// Modifier keys held while pressing a key or clicking.
public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let shift = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let control = KeyModifiers(rawValue: 1 << 3)
}
