import SwiftUI
import XCTest
@testable import TrueRPCMini

final class HotkeyConfigurationSwiftUITests: XCTestCase {
    // MARK: - KeyboardShortcut

    func test_keyboardShortcut_forCharacterKey_mapsKeyAndModifiers() {
        let shortcut = KeyCombination("]", modifiers: [.command, .shift]).keyboardShortcut

        XCTAssertEqual(shortcut.key, KeyEquivalent("]"))
        XCTAssertEqual(shortcut.modifiers, [.command, .shift])
    }

    func test_keyEquivalent_forNamedKeys_mapsToSwiftUIKeys() {
        let expected: [(KeyCombination.Key, KeyEquivalent)] = [
            (.return, .return),
            (.escape, .escape),
            (.delete, .delete),
            (.tab, .tab),
            (.space, .space),
            (.upArrow, .upArrow),
            (.downArrow, .downArrow),
            (.leftArrow, .leftArrow),
            (.rightArrow, .rightArrow),
        ]

        for (key, keyEquivalent) in expected {
            XCTAssertEqual(key.keyEquivalent, keyEquivalent, "\(key)")
        }
    }

    func test_keyboardShortcutForAction_whenBound_returnsMappedShortcut() {
        var sut = HotkeyConfiguration.standard
        sut[.executeRequest] = KeyCombination(.return, modifiers: [.command, .shift])

        let shortcut = sut.keyboardShortcut(for: .executeRequest)

        XCTAssertEqual(shortcut?.key, .return)
        XCTAssertEqual(shortcut?.modifiers, [.command, .shift])
    }

    func test_keyboardShortcutForAction_whenUnbound_returnsNil() {
        var sut = HotkeyConfiguration.standard
        sut[.closeTab] = nil

        XCTAssertNil(sut.keyboardShortcut(for: .closeTab))
    }

    // MARK: - Modifiers

    func test_eventModifiers_mapsEveryModifier() {
        let modifiers: KeyModifiers = [.command, .shift, .option, .control]

        XCTAssertEqual(modifiers.eventModifiers, [.command, .shift, .option, .control])
    }

    func test_initFromEventModifiers_keepsOnlyShortcutModifiers() {
        let modifiers = KeyModifiers([.option, .control, .capsLock, .numericPad, .function])

        XCTAssertEqual(modifiers, [.option, .control])
    }

    func test_symbols_ordersModifiersLikeMenus() {
        let modifiers: KeyModifiers = [.command, .shift, .option, .control]

        XCTAssertEqual(modifiers.symbols, "⌃⌥⇧⌘")
    }

    func test_symbols_forSingleModifier_returnsItsGlyph() {
        XCTAssertEqual(KeyModifiers.option.symbols, "⌥")
    }
}
