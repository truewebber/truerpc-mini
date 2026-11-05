import XCTest
@testable import TrueRPCMini

final class HotkeyConfigurationTests: XCTestCase {
    // MARK: - KeyCombination

    func test_keyCombinationInit_withoutModifiers_usesCommand() {
        let combination = KeyCombination("k")

        XCTAssertEqual(combination.key, .character("k"))
        XCTAssertEqual(combination.modifiers, .command)
    }

    // MARK: - Bindings

    func test_init_whenClosureReturnsCombination_bindsAction() {
        let combination = KeyCombination("k", modifiers: [.command, .option])

        let sut = HotkeyConfiguration(openInNewTabModifiers: .option) { action in
            action == .showAllTabs ? combination : nil
        }

        XCTAssertEqual(sut[.showAllTabs], combination)
    }

    func test_init_whenClosureReturnsNil_leavesActionUnbound() {
        let sut = HotkeyConfiguration(openInNewTabModifiers: .option) { _ in nil }

        XCTAssertNil(sut[.closeTab])
    }

    func test_subscript_whenAssigned_rebindsOnlyThatAction() {
        var sut = HotkeyConfiguration.standard
        let combination = KeyCombination("t", modifiers: [.command, .option])

        sut[.showAllTabs] = combination

        XCTAssertEqual(sut[.showAllTabs], combination)
        XCTAssertEqual(sut[.closeTab], HotkeyConfiguration.standard[.closeTab])
    }

    func test_subscript_whenAssignedNil_unbindsAction() {
        var sut = HotkeyConfiguration.standard

        sut[.executeRequest] = nil

        XCTAssertNil(sut[.executeRequest])
    }

    // MARK: - Standard

    func test_standard_bindsEachCombinationToOneAction() {
        let combinations = HotkeyAction.allCases.compactMap { HotkeyConfiguration.standard[$0] }

        XCTAssertEqual(Set(combinations).count, combinations.count)
    }

    // MARK: - Open in New Tab

    func test_opensInNewTab_whenConfiguredModifiersHeld_returnsTrue() {
        let sut = HotkeyConfiguration(openInNewTabModifiers: .option) { _ in nil }

        XCTAssertTrue(sut.opensInNewTab(withPressed: .option))
    }

    func test_opensInNewTab_whenExtraModifiersHeld_returnsTrue() {
        let sut = HotkeyConfiguration(openInNewTabModifiers: .option) { _ in nil }

        XCTAssertTrue(sut.opensInNewTab(withPressed: [.option, .shift]))
    }

    func test_opensInNewTab_whenConfiguredModifierMissing_returnsFalse() {
        let sut = HotkeyConfiguration(openInNewTabModifiers: [.option, .shift]) { _ in nil }

        XCTAssertFalse(sut.opensInNewTab(withPressed: .option))
    }

    func test_opensInNewTab_whenNoModifiersConfigured_returnsFalse() {
        let sut = HotkeyConfiguration(openInNewTabModifiers: []) { _ in nil }

        XCTAssertFalse(sut.opensInNewTab(withPressed: []))
        XCTAssertFalse(sut.opensInNewTab(withPressed: .option))
    }
}
