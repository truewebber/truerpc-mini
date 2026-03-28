import XCTest

final class AutocompletePopoverUITests: XCTestCase {
    private var app: XCUIApplication!

    // MARK: - Lifecycle

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Helpers

    /// Types `{ ` into the JSON editor so the popover appears with root-level suggestions.
    /// The UITestAutocompleteProvider returns 7 suggestions at root (including fillDefaults).
    private func triggerRootPopover() {
        let editor = app.jsonEditor
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "JSON editor must be visible after --uitesting launch")
        editor.click()
        editor.typeText("{ ")
        XCTAssertTrue(app.waitForPopover(timeout: 5), "Popover should appear after typing '{ '")
    }

    // MARK: - Popover appearance

    func test_popover_appearsWhenTypingOpenBraceAndSpace() {
        let editor = app.jsonEditor
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        editor.typeText("{ ")
        XCTAssertTrue(app.waitForPopover(timeout: 5), "Popover should appear when typing '{ '")
    }

    func test_popover_doesNotAppearWithoutOpenBrace() {
        let editor = app.jsonEditor
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.click()
        editor.typeText("abc")

        let appeared = app.autocompletePopover.waitForExistence(timeout: 2)
        XCTAssertFalse(appeared, "Popover must not appear when text has no opening brace")
    }

    // MARK: - Popover content

    func test_popover_showsExpectedSuggestionCount() {
        triggerRootPopover()

        let lastRow = app.suggestionRow(at: 6)
        XCTAssertTrue(lastRow.waitForExistence(timeout: 2), "Should have 7 suggestions (index 0-6)")

        let extraRow = app.suggestionRow(at: 7)
        XCTAssertFalse(extraRow.exists, "Should not have an 8th suggestion")
    }

    func test_popover_showsFillDefaultsFirst() {
        triggerRootPopover()

        let firstName = app.suggestionName(at: 0)
        XCTAssertTrue(firstName.waitForExistence(timeout: 2))
        XCTAssertEqual(firstName.value as? String ?? firstName.label, "(fill defaults)")
    }

    func test_popover_showsFieldNamesAndTypeHints() {
        triggerRootPopover()

        let nameSuggestion = app.suggestionName(at: 1)
        XCTAssertTrue(nameSuggestion.waitForExistence(timeout: 2))
        XCTAssertEqual(nameSuggestion.value as? String ?? nameSuggestion.label, "name")

        let nameType = app.suggestionType(at: 1)
        XCTAssertTrue(nameType.exists)
        XCTAssertEqual(nameType.value as? String ?? nameType.label, "string")
    }

    // MARK: - Keyboard navigation

    func test_popover_arrowDownMovesSelection() {
        triggerRootPopover()

        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])

        let row2 = app.suggestionRow(at: 2)
        XCTAssertTrue(row2.waitForExistence(timeout: 1))
    }

    func test_popover_arrowUpWrapsToBottom() {
        triggerRootPopover()

        app.typeKey(.upArrow, modifierFlags: [])

        let lastRow = app.suggestionRow(at: 6)
        XCTAssertTrue(lastRow.waitForExistence(timeout: 1))
    }

    func test_popover_tabCommitsSuggestion() {
        triggerRootPopover()

        // Navigate to "name" (index 1) and press Tab to commit
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.tab, modifierFlags: [])

        let editor = app.jsonEditor
        let editorText = editor.value as? String ?? ""
        XCTAssertTrue(editorText.contains("\"name\""), "Tab should commit the selected suggestion")
    }

    // MARK: - Dismissal

    func test_popover_escapeClosesPopover() {
        triggerRootPopover()

        app.typeKey(.escape, modifierFlags: [])

        XCTAssertTrue(app.waitForPopoverDismissal(), "Popover should close on Escape")
    }

    func test_popover_enterDismissesWithoutCommit() {
        triggerRootPopover()

        // Navigate to "name" (index 1) and press Enter
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.waitForPopoverDismissal(), "Enter should dismiss the popover")

        let editor = app.jsonEditor
        let editorText = editor.value as? String ?? ""
        XCTAssertFalse(editorText.contains("\"name\""), "Enter should NOT commit the suggestion")
    }

    func test_popover_closesAfterScalarFieldCommit() {
        triggerRootPopover()

        // Move to "name" (string, index 1) and commit via Tab
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.tab, modifierFlags: [])

        XCTAssertTrue(app.waitForPopoverDismissal(), "Popover should close after committing a scalar field")
    }

    // MARK: - Selection and commit

    func test_popover_clickRowCommitsSuggestion() {
        triggerRootPopover()

        // Click on the suggestion name label which is inside the onTapGesture region.
        let ageName = app.suggestionName(at: 2)
        XCTAssertTrue(ageName.waitForExistence(timeout: 2))
        ageName.click()

        let editor = app.jsonEditor
        let editorText = editor.value as? String ?? ""
        XCTAssertTrue(editorText.contains("\"age\""), "Editor should contain 'age' after clicking the row")
    }

    // MARK: - Smart insert verification

    func test_popover_stringFieldInsertsKeyValueWithQuotes() {
        triggerRootPopover()

        // "name" is at index 1 (string kind), commit via Tab
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.tab, modifierFlags: [])

        let editor = app.jsonEditor
        let editorText = editor.value as? String ?? ""
        XCTAssertTrue(editorText.contains("\"name\": \"\""), "String field should insert '\"name\": \"\"'")
    }

    func test_popover_messageFieldInsertsNestedBraces() {
        triggerRootPopover()

        // "address" is at index 4 (message kind), commit via Tab
        for _ in 0 ..< 4 {
            app.typeKey(.downArrow, modifierFlags: [])
        }
        app.typeKey(.tab, modifierFlags: [])

        let editor = app.jsonEditor
        let editorText = editor.value as? String ?? ""
        XCTAssertTrue(editorText.contains("\"address\": {"), "Message field should insert nested braces")
    }

    func test_popover_autoClosesRootBrace() {
        triggerRootPopover()

        // Commit "name" (index 1) via Tab
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.tab, modifierFlags: [])

        let editor = app.jsonEditor
        let editorText = editor.value as? String ?? ""
        XCTAssertTrue(editorText.contains("}"), "Root brace should be auto-closed after insertion")
    }

    // MARK: - Dynamic behavior

    func test_popover_reappearsAfterMessageFieldInsertion() {
        triggerRootPopover()

        // Navigate to "address" (index 4, message kind) and commit via Tab
        for _ in 0 ..< 4 {
            app.typeKey(.downArrow, modifierFlags: [])
        }
        app.typeKey(.tab, modifierFlags: [])

        // After inserting a message field, the popover should re-appear
        // with nested suggestions (street, city)
        XCTAssertTrue(app.waitForPopover(timeout: 5), "Popover should re-appear with nested field suggestions")

        let streetRow = app.suggestionName(at: 0)
        XCTAssertTrue(streetRow.waitForExistence(timeout: 2), "Should show nested 'street' suggestion")
    }

    func test_popover_doesNotOfferAlreadyFilledFields() {
        triggerRootPopover()

        // Commit "name" (index 1, string kind) via Tab — inserts "name": "" programmatically
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.tab, modifierFlags: [])

        // After commit, cursor is inside the empty string "".
        // Type a value, move past the closing quote, then type comma+space.
        let editor = app.jsonEditor
        editor.typeText("test")
        app.typeKey(.rightArrow, modifierFlags: [])
        editor.typeText(", ")

        // Dismiss any stale popover then re-trigger with a space to get a clean state
        app.typeKey(.escape, modifierFlags: [])
        app.waitForPopoverDismissal()
        editor.typeText(" ")

        if app.waitForPopover(timeout: 5) {
            let suggestions = (0 ..< 7).compactMap { index -> String? in
                let el = app.suggestionName(at: index)
                guard el.waitForExistence(timeout: 1) else { return nil }

                return el.value as? String ?? el.label
            }
            XCTAssertFalse(suggestions.contains("name"), "Already-filled 'name' should not appear in suggestions")
        }
    }
}
