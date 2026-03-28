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

    // MARK: - Enter key dismisses and passes through

    func test_enterKey_whenPopoverVisible_dismissesAndDoesNotConsume() {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [AutocompleteSuggestion(name: "field", typeHint: "string", kind: .string)]
        vm.isVisible = true

        let textView = NSTextView()
        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertFalse(consumed, "Enter must not be consumed so NSTextView inserts a newline")
        XCTAssertFalse(vm.isVisible, "Popover must be dismissed on Enter")
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

        coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"count\": "))
    }

    // MARK: - Smart insert — bool kind (via Tab)

    func test_commitSelection_boolKind_insertsKeyColonSpace() {
        let suggestion = AutocompleteSuggestion(name: "active", typeHint: "bool", kind: .bool)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"active\": "))
    }

    // MARK: - Smart insert — message kind (via Tab)

    func test_commitSelection_messageKind_insertsNestedBraces() {
        let suggestion = AutocompleteSuggestion(name: "address", typeHint: "Address", kind: .message)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

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

        coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"ACTIVE\""))
    }

    // MARK: - Smart insert — repeated kind (via Tab)

    func test_commitSelection_repeatedKind_insertsEmptyArray() {
        let suggestion = AutocompleteSuggestion(name: "tags", typeHint: "string[]", kind: .repeated)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

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

        coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertEqual(textView.string, originalText)
        XCTAssertFalse(vm.isVisible)
    }

    // MARK: - smartInsertComponents static method

    func test_smartInsertComponents_string_returnsQuotedKeyAndEmptyValue() {
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (text, cursorBack) = JSONTextEditor.Coordinator.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"name\": \"\"")
        XCTAssertEqual(cursorBack, 1)
    }

    func test_smartInsertComponents_number_returnsKeyColonSpace() {
        let suggestion = AutocompleteSuggestion(name: "age", typeHint: "int32", kind: .number)
        let (text, cursorBack) = JSONTextEditor.Coordinator.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"age\": ")
        XCTAssertEqual(cursorBack, 0)
    }

    func test_smartInsertComponents_bool_returnsKeyColonSpace() {
        let suggestion = AutocompleteSuggestion(name: "active", typeHint: "bool", kind: .bool)
        let (text, cursorBack) = JSONTextEditor.Coordinator.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"active\": ")
        XCTAssertEqual(cursorBack, 0)
    }

    func test_smartInsertComponents_message_returnsNestedBraces() {
        let suggestion = AutocompleteSuggestion(name: "addr", typeHint: "Address", kind: .message)
        let (text, cursorBack) = JSONTextEditor.Coordinator.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"addr\": {\n  \n}")
        XCTAssertEqual(cursorBack, 2)
    }

    func test_smartInsertComponents_enum_returnsQuotedName() {
        let suggestion = AutocompleteSuggestion(name: "ACTIVE", typeHint: "Status", kind: .enum)
        let (text, cursorBack) = JSONTextEditor.Coordinator.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"ACTIVE\"")
        XCTAssertEqual(cursorBack, 0)
    }

    func test_smartInsertComponents_repeated_returnsEmptyArray() {
        let suggestion = AutocompleteSuggestion(name: "tags", typeHint: "string[]", kind: .repeated)
        let (text, cursorBack) = JSONTextEditor.Coordinator.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"tags\": []")
        XCTAssertEqual(cursorBack, 1)
    }

    func test_smartInsertComponents_fillDefaults_returnsEmptyString() {
        let suggestion = AutocompleteSuggestion(name: "fillDefaults", typeHint: "", kind: .fillDefaults)
        let (text, cursorBack) = JSONTextEditor.Coordinator.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "")
        XCTAssertEqual(cursorBack, 0)
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

    // MARK: - unclosedBraceCount

    func test_unclosedBraceCount_balanced_returnsZero() {
        XCTAssertEqual(JSONTextEditor.Coordinator.unclosedBraceCount(in: "{\"a\": 1}"), 0)
    }

    func test_unclosedBraceCount_oneOpen_returnsOne() {
        XCTAssertEqual(JSONTextEditor.Coordinator.unclosedBraceCount(in: "{\"a\": 1"), 1)
    }

    func test_unclosedBraceCount_nestedOpen_returnsTwo() {
        XCTAssertEqual(JSONTextEditor.Coordinator.unclosedBraceCount(in: "{\"a\": {\"b\": 1"), 2)
    }

    func test_unclosedBraceCount_bracesInsideString_ignored() {
        XCTAssertEqual(JSONTextEditor.Coordinator.unclosedBraceCount(in: "{\"data\": \"{{{}\"}"), 0)
    }

    func test_unclosedBraceCount_empty_returnsZero() {
        XCTAssertEqual(JSONTextEditor.Coordinator.unclosedBraceCount(in: ""), 0)
    }

    func test_unclosedBraceCount_moreClosed_returnsZero() {
        XCTAssertEqual(JSONTextEditor.Coordinator.unclosedBraceCount(in: "}}"), 0)
    }

    func test_unclosedBraceCount_escapedQuoteInsideString_correctCount() {
        XCTAssertEqual(JSONTextEditor.Coordinator.unclosedBraceCount(in: "{\"key\": \"val\\\"ue\""), 1)
    }

    // MARK: - Smart insert auto-closes braces

    func test_smartInsert_intoUnclosedRoot_appendsClosingBrace() {
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

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

        coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        let braceCount = textView.string.count(where: { $0 == "}" })
        XCTAssertEqual(braceCount, 1, "Should not add extra closing brace")
    }
}
