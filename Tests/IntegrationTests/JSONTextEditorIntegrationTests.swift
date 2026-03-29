import AppKit
import SwiftUI
import XCTest
@testable import TrueRPCMini

@MainActor
final class JSONTextEditorIntegrationTests: XCTestCase {
    // MARK: - Helpers

    private func makeProtoFile() -> ProtoFile {
        let method = TrueRPCMini.Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false)
        let service = Service(name: "UserService", methods: [method])
        return ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/tmp/test.proto"),
            services: [service])
    }

    private func makeCoordinator(
        provider: AutocompleteProviderProtocol = MockAutocompleteProvider(),
        protoFile: ProtoFile? = nil)
        -> (JSONTextEditor.Coordinator, AutocompleteViewModel)
    {
        let resolver = JsonPathResolver()
        let vm = AutocompleteViewModel(provider: provider, resolver: resolver, methodInputType: ".test.GetUserRequest")
        let resolvedProtoFile = protoFile ?? makeProtoFile()
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let editor = JSONTextEditor(
            text: binding,
            autocompleteViewModel: vm,
            protoFile: resolvedProtoFile)
        return (editor.makeCoordinator(), vm)
    }

    private func makeTextView(text: String = "") -> NSTextView {
        let textView = NSTextView()
        textView.string = text
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
        return textView
    }

    // MARK: - textDidChange triggers autocomplete

    func test_textChange_triggersAutocompleteViewModelTextDidChange() async throws {
        let suggestion = AutocompleteSuggestion(name: "userId", typeHint: "int64", kind: .number)
        let provider = MockAutocompleteProvider(stubSuggestions: [suggestion])
        let (coordinator, vm) = makeCoordinator(provider: provider)

        let textView = NSTextView()
        textView.string = "{ "

        let notification = Notification(name: NSText.didChangeNotification, object: textView)
        coordinator.textDidChange(notification)

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(vm.suggestions.isEmpty)
        XCTAssertTrue(vm.isVisible)
    }

    // MARK: - Escape key

    func test_escapeKey_dismissesPopover() {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [AutocompleteSuggestion(name: "field", typeHint: "string", kind: .string)]
        vm.isVisible = true

        let textView = NSTextView()
        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSResponder.cancelOperation(_:)))

        XCTAssertTrue(consumed)
        XCTAssertFalse(vm.isVisible)
    }

    func test_escapeKey_whenPopoverNotVisible_isNotConsumed() {
        let (coordinator, vm) = makeCoordinator()
        vm.isVisible = false

        let textView = NSTextView()
        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSResponder.cancelOperation(_:)))

        XCTAssertFalse(consumed)
    }

    // MARK: - Arrow keys

    func test_arrowDown_whenPopoverVisible_isConsumed() {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [
            AutocompleteSuggestion(name: "a", typeHint: "string", kind: .string),
            AutocompleteSuggestion(name: "b", typeHint: "string", kind: .string),
        ]
        vm.isVisible = true

        let textView = NSTextView()
        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.moveDown(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(vm.selectedIndex, 1)
    }

    func test_arrowUp_whenPopoverVisible_isConsumed() {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [
            AutocompleteSuggestion(name: "a", typeHint: "string", kind: .string),
            AutocompleteSuggestion(name: "b", typeHint: "string", kind: .string),
        ]
        vm.isVisible = true

        let textView = NSTextView()
        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.moveUp(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(vm.selectedIndex, 1) // wraps from 0 to last
    }

    func test_arrowDown_whenPopoverNotVisible_isNotConsumed() {
        let (coordinator, vm) = makeCoordinator()
        vm.isVisible = false

        let textView = NSTextView()
        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.moveDown(_:)))

        XCTAssertFalse(consumed)
    }

    // MARK: - Tab key commits selection

    func test_tabKey_commitsSuggestion() {
        let suggestion = AutocompleteSuggestion(name: "username", typeHint: "string", kind: .string)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")
        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(consumed)
        XCTAssertTrue(textView.string.contains("\"username\": \"\""))
    }

    // MARK: - Enter key dismisses popover and applies smart newline

    func test_enterKey_whenPopoverVisible_dismissesAndAppliesSmartNewline() {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [AutocompleteSuggestion(name: "field", typeHint: "string", kind: .string)]
        vm.isVisible = true

        let textView = NSTextView()
        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed, "Enter applies smart indentation and is always consumed")
        XCTAssertFalse(vm.isVisible, "Popover must be dismissed on Enter")
    }

    // MARK: - Enter key smart indentation (AC-6 through AC-10)

    func test_enter_afterOpenBrace_indentsNextLine() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        textView.string = "{"
        textView.setSelectedRange(NSRange(location: 1, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(textView.string, "{\n  ")
        XCTAssertEqual(textView.selectedRange().location, 4)
    }

    func test_enter_afterOpenBracket_indentsNextLine() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        textView.string = "["
        textView.setSelectedRange(NSRange(location: 1, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(textView.string, "[\n  ")
        XCTAssertEqual(textView.selectedRange().location, 4)
    }

    func test_enter_insideEmptyBraces_splitsBracesAndIndents() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        textView.string = "{}"
        textView.setSelectedRange(NSRange(location: 1, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(textView.string, "{\n  \n}")
        XCTAssertEqual(textView.selectedRange().location, 4)
    }

    func test_enter_insideBracesWithWhitespace_splitsBracesAndIndents() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        textView.string = "{   }"
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(textView.string, "{\n  \n}")
        XCTAssertEqual(textView.selectedRange().location, 4)
    }

    func test_enter_atEndOfFieldLine_maintainsIndent() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        let text = "  \"field\": \"value\""
        textView.string = text
        textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(textView.string, "  \"field\": \"value\"\n  ")
        XCTAssertEqual(textView.selectedRange().location, text.utf16.count + 3)
    }

    func test_enter_withTrailingComma_maintainsIndent() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        let text = "  \"field\": \"value\","
        textView.string = text
        textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(textView.string, "  \"field\": \"value\",\n  ")
        XCTAssertEqual(textView.selectedRange().location, text.utf16.count + 3)
    }

    func test_enter_midLine_splitsAndMaintainsIndent() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        textView.string = "  ab"
        textView.setSelectedRange(NSRange(location: 3, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(textView.string, "  a\n  b")
        XCTAssertEqual(textView.selectedRange().location, 6)
    }

    func test_enter_withSelection_replacesAndIndents() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        textView.string = "  abcd"
        textView.setSelectedRange(NSRange(location: 3, length: 2))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(textView.string, "  a\n  d")
        XCTAssertEqual(textView.selectedRange().location, 6)
    }

    func test_enter_afterClosingBraceAtEndOfValueLine_maintainsIndent() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        let text = "  \"key\": {}"
        textView.string = text
        textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(textView.string, "  \"key\": {}\n  ")
    }

    func test_enter_afterClosingBraceOnOwnLine_maintainsIndent() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        let text = "  }"
        textView.string = text
        textView.setSelectedRange(NSRange(location: text.utf16.count, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed)
        XCTAssertEqual(textView.string, "  }\n  ")
    }

    func test_enter_insideStringLiteral_noSmartIndent() {
        let (coordinator, _) = makeCoordinator()
        let textView = NSTextView()
        textView.string = "\"hello\""
        textView.setSelectedRange(NSRange(location: 3, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertFalse(consumed, "Enter inside a string literal must not be consumed")
    }

    // MARK: - Smart insert — string kind (via Tab)

    func test_commitSelection_stringKind_insertsKeyColonEmptyString() {
        let suggestion = AutocompleteSuggestion(name: "username", typeHint: "string", kind: .string)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(consumed)
        XCTAssertTrue(textView.string.contains("\"username\": \"\""))
    }

    // MARK: - Smart insert — number kind (via Tab)

    func test_commitSelection_numberKind_insertsKeyColonSpace() {
        let suggestion = AutocompleteSuggestion(name: "count", typeHint: "int32", kind: .number)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"count\": "))
    }

    // MARK: - Smart insert — bool kind (via Tab)

    func test_commitSelection_boolKind_insertsKeyColonSpace() {
        let suggestion = AutocompleteSuggestion(name: "active", typeHint: "bool", kind: .bool)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"active\": "))
    }

    // MARK: - Smart insert — message kind (via Tab)

    func test_commitSelection_messageKind_insertsNestedBraces() {
        let suggestion = AutocompleteSuggestion(name: "address", typeHint: "Address", kind: .message)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"address\": {"))
        XCTAssertTrue(textView.string.contains("}"))
    }

    // MARK: - Smart insert — enum kind (via Tab)

    func test_commitSelection_enumKind_insertsQuotedName() {
        let suggestion = AutocompleteSuggestion(name: "ACTIVE", typeHint: "Status", kind: .enum)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  \"status\": ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"ACTIVE\""))
    }

    // MARK: - Smart insert — repeated kind (via Tab)

    func test_commitSelection_repeatedKind_insertsEmptyArray() {
        let suggestion = AutocompleteSuggestion(name: "tags", typeHint: "string[]", kind: .repeated)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"tags\": []"))
    }

    // MARK: - Smart insert — fillDefaults kind (via Tab)

    func test_commitSelection_fillDefaultsKind_doesNotInsertText() {
        let suggestion = AutocompleteSuggestion(name: "fillDefaults", typeHint: "", kind: .fillDefaults)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")
        let originalText = textView.string

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertEqual(textView.string, originalText)
        XCTAssertFalse(vm.isVisible)
    }

    // MARK: - Unrecognized command selectors not consumed

    func test_unrecognizedCommand_whenPopoverVisible_isNotConsumed() {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [AutocompleteSuggestion(name: "f", typeHint: "s", kind: .string)]
        vm.isVisible = true

        let textView = NSTextView()
        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.deleteBackward(_:)))

        XCTAssertFalse(consumed)
    }

    // MARK: - Smart insert auto-closes braces

    func test_smartInsert_intoUnclosedRoot_appendsClosingBrace() {
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"name\": \"\""))
        XCTAssertTrue(textView.string.hasSuffix("}"), "Root brace must be auto-closed, got: \(textView.string)")
    }

    func test_smartInsert_intoAlreadyClosedRoot_doesNotDuplicateBrace() {
        let suggestion = AutocompleteSuggestion(name: "age", typeHint: "int32", kind: .number)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = NSTextView()
        textView.string = "{\n  \n}"
        textView.setSelectedRange(NSRange(location: 4, length: 0))

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        let braceCount = textView.string.count(where: { $0 == "}" })
        XCTAssertEqual(braceCount, 1, "Should not add extra closing brace")
    }

    func test_applySmartInsert_direct_insertsBraceBeforeArrayBracket() {
        let suggestion = AutocompleteSuggestion(name: "id", typeHint: "string", kind: .string)
        let (coordinator, _) = makeCoordinator()
        let prefix = "{\n  \"names\": [\n    {\n      "
        let suffix = "\n  ]\n}"
        let textView = NSTextView()
        textView.string = prefix + suffix
        textView.setSelectedRange(NSRange(location: prefix.utf16.count, length: 0))

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        XCTAssertTrue(textView.string.contains("\"id\": \"\"\n      }"), textView.string)
    }

    /// Auto-closing `}` must go before the array's `]`, not at EOF, when the object lives inside `[]`.
    func test_smartInsert_fieldInsideArrayObject_closesBraceBeforeArrayBracket() {
        let suggestion = AutocompleteSuggestion(name: "id", typeHint: "string", kind: .string)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let prefix = "{\n  \"names\": [\n    {\n      "
        let suffix = "\n  ]\n}"
        let textView = NSTextView()
        textView.string = prefix + suffix
        textView.setSelectedRange(NSRange(location: prefix.utf16.count, length: 0))

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"id\": \"\""), textView.string)
        XCTAssertTrue(
            textView.string.contains("\"id\": \"\"\n      }"),
            "Inner object should close immediately after the field; got: \(textView.string)")
        let ns = textView.string as NSString
        let idEnd = ns.range(of: "\"id\": \"\"").location + ns.range(of: "\"id\": \"\"").length
        let braceAfterValue = ns.range(
            of: "\n      }",
            options: [],
            range: NSRange(location: idEnd, length: ns.length - idEnd))
        XCTAssertNotEqual(braceAfterValue.location, NSNotFound, textView.string)
        let bracketRange = ns.range(of: "\n  ]")
        XCTAssertNotEqual(bracketRange.location, NSNotFound, textView.string)
        XCTAssertLessThan(
            braceAfterValue.location,
            bracketRange.location,
            "Closing brace must appear before the array `]`; got: \(textView.string)")
    }

    // MARK: - applySmartInsert with partial key text

    func test_applySmartInsert_withPartialStringKey_replacesPartialTextInsteadOfAppending() {
        // User typed `{"num` (partial key), then presses Tab to insert `numbers` field.
        // Expected: `{"num` is replaced by `"numbers": ""`, not appended after.
        let suggestion = AutocompleteSuggestion(name: "numbers", typeHint: "string", kind: .string)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{\"num")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        XCTAssertFalse(
            textView.string.contains("num\"numbers"),
            "Partial text must be replaced, not kept: \(textView.string)")
        XCTAssertTrue(
            textView.string.contains("\"numbers\": \"\""),
            "Full field snippet must be present: \(textView.string)")
    }

    func test_applySmartInsert_withOpeningQuoteOnly_replacesQuote() {
        // User typed `{"` (just the opening quote), then presses Tab.
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{\"")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        XCTAssertTrue(
            textView.string.contains("\"name\": \"\""),
            "Snippet must replace the lone opening quote: \(textView.string)")
        XCTAssertFalse(
            textView.string.contains("\"\"name"),
            "No doubled quote: \(textView.string)")
    }

    func test_applySmartInsert_withNoPartialKey_insertsAtCursor() {
        // Cursor is after `{` with no partial key — normal insert path unchanged.
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{\n  ")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        XCTAssertTrue(
            textView.string.contains("\"name\": \"\""),
            "Normal insert must still work: \(textView.string)")
    }

    // MARK: - applySmartInsert with bare text

    func test_applySmartInsert_withBareText_replacesBareTextInsteadOfAppending() {
        // User typed `{dfdf` (bare, no opening quote) then presses Tab.
        // Expected: `dfdf` is replaced by the snippet, not left in place.
        let suggestion = AutocompleteSuggestion(name: "numbers", typeHint: "string", kind: .string)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{dfdf")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        XCTAssertFalse(
            textView.string.contains("dfdf\"numbers"),
            "Bare text must be replaced, not kept: \(textView.string)")
        XCTAssertTrue(
            textView.string.contains("\"numbers\": \"\""),
            "Full field snippet must be present: \(textView.string)")
    }

    // MARK: - Indented closing-brace suffix (OPE-248)

    func test_autocomplete_fieldAtDepth0_closingBraceHasNoIndent() {
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{\n")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        let result = textView.string
        XCTAssertTrue(
            result.hasSuffix("\n}"),
            "At depth 0, closing brace must have no indent; got: \(result)")
        XCTAssertFalse(
            result.hasSuffix("\n  }"),
            "At depth 0, no leading spaces before closing brace; got: \(result)")
    }

    func test_autocomplete_fieldAtDepth1_closingBraceHasTwoSpaces() {
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{\n  ")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        let result = textView.string
        XCTAssertTrue(
            result.hasSuffix("\n  }"),
            "At depth 1 (2-space indent), closing brace must have 2 leading spaces; got: \(result)")
    }

    func test_autocomplete_nestedMessageAtDepth2_closingBracesHaveCorrectIndent() {
        let suggestion = AutocompleteSuggestion(name: "id", typeHint: "string", kind: .string)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{\n  \"nested\": {\n    ")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        let result = textView.string
        XCTAssertTrue(
            result.contains("\n    }"),
            "Inner closer must have 4-space indent; got: \(result)")
        XCTAssertTrue(
            result.hasSuffix("\n  }"),
            "Outer (trailing) closer must have 2-space indent; got: \(result)")
        XCTAssertFalse(
            result.hasSuffix("\n    }"),
            "Trailing closer must not retain the 4-space cursor indent; got: \(result)")
    }
}
