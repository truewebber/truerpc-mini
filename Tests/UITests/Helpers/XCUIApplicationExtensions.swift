import XCTest

extension XCUIApplication {
    var jsonEditor: XCUIElement {
        textViews["json_editor"].firstMatch
    }

    /// The autocomplete popover's root element.
    /// NSPopover content may appear as a group, other, or scroll view in the accessibility tree.
    var autocompletePopover: XCUIElement {
        let query = descendants(matching: .any).matching(identifier: "autocomplete_popover")
        return query.firstMatch
    }

    func suggestionRow(at index: Int) -> XCUIElement {
        descendants(matching: .any).matching(identifier: "suggestion_row_\(index)").firstMatch
    }

    func suggestionName(at index: Int) -> XCUIElement {
        descendants(matching: .any).matching(identifier: "suggestion_name_\(index)").firstMatch
    }

    func suggestionType(at index: Int) -> XCUIElement {
        descendants(matching: .any).matching(identifier: "suggestion_type_\(index)").firstMatch
    }

    /// Waits for the autocomplete popover to appear within the given timeout.
    @discardableResult
    func waitForPopover(timeout: TimeInterval = 3) -> Bool {
        autocompletePopover.waitForExistence(timeout: timeout)
    }

    /// Waits until the autocomplete popover disappears.
    @discardableResult
    func waitForPopoverDismissal(timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: autocompletePopover)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
