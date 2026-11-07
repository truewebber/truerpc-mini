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
        protoFile: ProtoFile? = nil,
        includeProtoFile: Bool = true,
        formatInlineJSON: ((String) -> String?)? = nil)
        -> (JSONTextEditor.Coordinator, AutocompleteViewModel)
    {
        let resolver = JsonPathResolver()
        let vm = AutocompleteViewModel(provider: provider, resolver: resolver, methodInputType: ".test.GetUserRequest")
        let resolvedProtoFile: ProtoFile? = includeProtoFile ? (protoFile ?? makeProtoFile()) : nil
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let editor = JSONTextEditor(
            text: binding,
            autocompleteViewModel: vm,
            protoFile: resolvedProtoFile,
            smartInsert: SmartInsertService(),
            formatInlineJSON: formatInlineJSON)
        return (editor.makeCoordinator(), vm)
    }

    private func makeMetadataCoordinator() -> JSONTextEditor.Coordinator {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let editor = JSONTextEditor(
            text: binding,
            smartInsert: SmartInsertService(),
            formatInlineJSON: { json in
                JsonInlineDocument.pretty(json) { try JsonFormatter().format($0) }
            })
        return editor.makeCoordinator()
    }

    private func publishEdit(
        _ coordinator: JSONTextEditor.Coordinator,
        in textView: NSTextView)
        async throws
    {
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        try await Task.sleep(for: .milliseconds(300))
    }

    private func laidOutTextView(_ text: String, width: CGFloat) throws -> (NSTextView, NSWindow) {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 220))
        textView.string = text
        textView.font = JsonEditorMetrics.font
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 220),
            styleMask: [.titled],
            backing: .buffered,
            defer: false)
        window.contentView = textView
        window.orderFrontRegardless()
        textView.layoutSubtreeIfNeeded()
        try textView.layoutManager?.ensureLayout(for: XCTUnwrap(textView.textContainer))
        return (textView, window)
    }

    private func visibleTypeLabel(in textView: NSTextView) -> NSTextField? {
        textView.subviews.compactMap { $0 as? NSTextField }.first { !$0.isHidden && !$0.stringValue.isEmpty }
    }

    private func scrollingTextView(_ text: String, height: CGFloat) throws -> (NSTextView, NSWindow) {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.frame = NSRect(x: 0, y: 0, width: 420, height: height)
        let textView = try XCTUnwrap(scrollView.documentView as? NSTextView)
        textView.string = text
        textView.font = JsonEditorMetrics.font
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: height),
            styleMask: [.titled],
            backing: .buffered,
            defer: false)
        window.contentView = scrollView
        window.orderFrontRegardless()
        textView.layoutSubtreeIfNeeded()
        try textView.layoutManager?.ensureLayout(for: XCTUnwrap(textView.textContainer))
        return (textView, window)
    }

    private func lineFragment(in textView: NSTextView, utf16: Int) -> NSRect? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return nil }

        let length = (textView.string as NSString).length
        let index = min(max(0, utf16), max(length - 1, 0))
        guard length > 0 else { return nil }

        layoutManager.ensureLayout(for: textContainer)
        let glyph = layoutManager.glyphIndexForCharacter(at: index)
        var rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        rect.origin.x += textView.textContainerOrigin.x
        rect.origin.y += textView.textContainerOrigin.y
        return rect
    }

    private func caretAnchorX(in textView: NSTextView) -> Double {
        let location = textView.selectedRange().location
        let length = (textView.string as NSString).length
        let index = min(location, max(length - 1, 0))
        let glyph = glyphRect(in: textView, utf16: index)
        let x = location >= length ? (glyph?.maxX ?? 0) : (glyph?.minX ?? 0)
        return Double(x)
    }

    private func popoverWindowFrame(_ coordinator: JSONTextEditor.Coordinator) -> NSRect? {
        coordinator.autocompletePopover.contentViewController?.view.window?.frame
    }

    private func glyphRect(in textView: NSTextView, utf16: Int) -> NSRect? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              utf16 >= 0,
              utf16 < (textView.string as NSString).length
        else { return nil }

        layoutManager.ensureLayout(for: textContainer)
        let glyph = layoutManager.glyphIndexForCharacter(at: utf16)
        var rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
        rect.origin.x += textView.textContainerOrigin.x
        rect.origin.y += textView.textContainerOrigin.y
        return rect
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

    func test_popover_caretOnTheFirstLine_opensBelowThatLine() throws {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [
            AutocompleteSuggestion(name: "fillDefaults", typeHint: "all fields", kind: .fillDefaults),
            AutocompleteSuggestion(name: "names", typeHint: "User[]", kind: .repeated),
        ]
        let (textView, window) = try laidOutTextView("{\n  \"names\": []\n}", width: 420)
        textView.isVerticallyResizable = false
        textView.setFrameSize(NSSize(width: 420, height: 220))
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: 1, length: 0))

        let placement = coordinator.autocompletePopoverPlacement(in: textView)
        let line = try XCTUnwrap(lineFragment(in: textView, utf16: 0))

        XCTAssertEqual(placement?.side, .below)
        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertEqual(frame.minY, Double(line.maxY) + PlaceAutocompletePopover.gap, accuracy: 1)
        XCTAssertLessThan(frame.minY, Double(textView.bounds.midY))
        let caretX = caretAnchorX(in: textView)
        XCTAssertGreaterThanOrEqual(caretX, frame.minX)
        XCTAssertLessThanOrEqual(caretX, frame.maxX)

        coordinator.showAutocompletePopover(in: textView)
        let popoverFrame = try XCTUnwrap(popoverWindowFrame(coordinator))
        let caretScreen = textView.firstRect(forCharacterRange: NSRange(location: 0, length: 1), actualRange: nil)
        XCTAssertEqual(popoverFrame.maxY, caretScreen.minY, accuracy: 12)
        XCTAssertFalse(popoverFrame.intersects(caretScreen))
    }

    func test_popover_caretAtTheBottomOfTheVisibleEditor_opensAboveTheLine() throws {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = (0 ..< 12).map {
            AutocompleteSuggestion(name: "field\($0)", typeHint: "string", kind: .string)
        }
        let lines = (0 ..< 40).map { "\"field\($0)\": \"\"" }.joined(separator: ",\n")
        let (textView, window) = try scrollingTextView("{\n\(lines)\n}", height: 180)
        XCTAssertNotNil(window.contentView)
        let end = (textView.string as NSString).length - 1
        textView.setSelectedRange(NSRange(location: end, length: 0))
        let documentHeight = textView.bounds.height
        textView.scroll(NSPoint(x: 0, y: max(0, documentHeight - textView.visibleRect.height)))
        textView.layoutSubtreeIfNeeded()

        let placement = coordinator.autocompletePopoverPlacement(in: textView)
        let line = try XCTUnwrap(lineFragment(in: textView, utf16: end))

        XCTAssertEqual(placement?.side, .above)
        let frame = try XCTUnwrap(placement?.frame)
        XCTAssertEqual(frame.maxY, Double(line.minY) - PlaceAutocompletePopover.gap, accuracy: 1)
        XCTAssertLessThanOrEqual(frame.maxY, Double(textView.bounds.maxY))
    }

    func test_popover_tallListOnTheFirstLine_shrinksToTheFreeRoom() throws {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [
            AutocompleteSuggestion(name: "id", typeHint: "string", kind: .string),
        ]
        let (textView, window) = try laidOutTextView("{\n}", width: 420)
        textView.isVerticallyResizable = false
        textView.setFrameSize(NSSize(width: 420, height: 220))
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        let oneRow = try XCTUnwrap(coordinator.autocompletePopoverPlacement(in: textView))

        vm.suggestions = (0 ..< 30).map {
            AutocompleteSuggestion(name: "field\($0)", typeHint: "string", kind: .string)
        }
        let manyRows = try XCTUnwrap(coordinator.autocompletePopoverPlacement(in: textView))

        XCTAssertEqual(manyRows.side, .below)
        XCTAssertEqual(manyRows.frame.y, oneRow.frame.y, accuracy: 1)
        XCTAssertGreaterThan(manyRows.frame.height, oneRow.frame.height)
        XCTAssertLessThan(manyRows.frame.height, Double(AutocompletePopoverSize.maxHeight))
        XCTAssertLessThanOrEqual(manyRows.frame.maxY, Double(textView.bounds.maxY) + 1)
    }

    func test_popover_caretScrolledOutOfView_staysClosed() throws {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [
            AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string),
        ]
        let lines = (0 ..< 80).map { "\"field\($0)\": \"\"" }.joined(separator: ",\n")
        let (textView, window) = try scrollingTextView("{\n\(lines)\n}", height: 160)
        XCTAssertNotNil(window.contentView)
        let end = (textView.string as NSString).length - 1
        textView.setSelectedRange(NSRange(location: end, length: 0))
        textView.scroll(NSPoint.zero)
        textView.layoutSubtreeIfNeeded()

        XCTAssertNil(coordinator.autocompletePopoverPlacement(in: textView))
        coordinator.showAutocompletePopover(in: textView)
        XCTAssertFalse(coordinator.autocompletePopover.isShown)
    }

    func test_popover_wrappedCaret_anchorsToTheCaretNotTheLineStart() throws {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [
            AutocompleteSuggestion(name: "value", typeHint: "string", kind: .string),
        ]
        let (textView, window) = try laidOutTextView(String(repeating: "abcdef", count: 20), width: 80)
        XCTAssertNotNil(window.contentView)
        let end = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: end, length: 0))

        let placement = try XCTUnwrap(coordinator.autocompletePopoverPlacement(in: textView))
        let caretX = caretAnchorX(in: textView)
        let lineStart = try Double(XCTUnwrap(lineFragment(in: textView, utf16: 0)).minX) + 1
        XCTAssertGreaterThanOrEqual(caretX, placement.frame.minX)
        XCTAssertLessThanOrEqual(caretX, placement.frame.maxX)
        XCTAssertGreaterThan(abs(caretX - lineStart), 20)
    }

    func test_popover_caretMovesToTheNextLine_followsThatLine() throws {
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [
            AutocompleteSuggestion(name: "names", typeHint: "User[]", kind: .repeated),
        ]
        let (textView, window) = try laidOutTextView("{\n  \"names\": []\n}", width: 420)
        textView.isVerticallyResizable = false
        textView.setFrameSize(NSSize(width: 420, height: 220))
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: 1, length: 0))
        let first = try XCTUnwrap(coordinator.autocompletePopoverPlacement(in: textView))

        let nextLine = (textView.string as NSString).range(of: "\"names\"").location
        textView.setSelectedRange(NSRange(location: nextLine, length: 0))
        let second = try XCTUnwrap(coordinator.autocompletePopoverPlacement(in: textView))

        XCTAssertEqual(first.side, .below)
        XCTAssertEqual(second.side, .below)
        XCTAssertGreaterThan(second.frame.y, first.frame.y + 8)
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

    // MARK: - Enter key — autocomplete update is not suppressed after newline

    /// Positive: `textDidChange` is not suppressed after Enter so the autocomplete Task
    /// fires and populates suggestions when the provider has them.
    ///
    /// In production `textView.delegate = coordinator` is wired up in `makeNSView`.
    /// Replicating that here lets `textView.didChangeText()` reach the coordinator.
    func test_enterKey_schedulesAutocompleteUpdateAfterNewline() async throws {
        let suggestion = AutocompleteSuggestion(name: "userId", typeHint: "int64", kind: .number)
        let provider = MockAutocompleteProvider(stubSuggestions: [suggestion])
        let (coordinator, vm) = makeCoordinator(provider: provider)

        let textView = NSTextView()
        textView.delegate = coordinator // mirrors makeNSView wiring
        textView.string = "{\n  "
        textView.setSelectedRange(NSRange(location: 4, length: 0))

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(
            vm.suggestions.isEmpty,
            "Autocomplete must update after Enter; suppression was incorrectly blocking this before the fix")
    }

    /// Positive: when the popover is visible, Enter dismisses it synchronously; the
    /// autocomplete pipeline still fires asynchronously and re-populates suggestions.
    func test_enterKey_whenPopoverVisible_dismissesImmediatelyThenReschedulesAutocomplete() async throws {
        let suggestion = AutocompleteSuggestion(name: "field", typeHint: "string", kind: .string)
        let provider = MockAutocompleteProvider(stubSuggestions: [suggestion])
        let (coordinator, vm) = makeCoordinator(provider: provider)
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = NSTextView()
        textView.delegate = coordinator
        textView.string = "{\n  "
        textView.setSelectedRange(NSRange(location: 4, length: 0))

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertFalse(vm.isVisible, "Popover must be dismissed synchronously on Enter")

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(
            vm.suggestions.isEmpty,
            "Autocomplete must re-trigger after Enter lands in a valid context")
    }

    /// Negative: when the provider returns no suggestions the popover stays hidden, even
    /// though the autocomplete pipeline fires (it just has nothing to show).
    func test_enterKey_whenNoSuggestionsAvailable_popoverRemainsHidden() async throws {
        let (coordinator, vm) = makeCoordinator() // default provider — always returns []

        let textView = NSTextView()
        textView.delegate = coordinator
        textView.string = "{\n  "
        textView.setSelectedRange(NSRange(location: 4, length: 0))

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(vm.isVisible, "Popover must not appear when provider returns no suggestions")
    }

    /// Negative / corner: editor without an autocomplete VM must not crash on Enter and
    /// must still apply smart indentation.
    func test_enterKey_withNoAutocompleteViewModel_appliesSmartNewlineWithoutCrash() {
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let editor = JSONTextEditor(text: binding, smartInsert: SmartInsertService())
        let coordinator = editor.makeCoordinator()

        let textView = NSTextView()
        textView.string = "{"
        textView.setSelectedRange(NSRange(location: 1, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed, "Smart newline must still be applied when there is no autocomplete VM")
        XCTAssertEqual(textView.string, "{\n  ", "Smart indentation must work without autocomplete VM")
    }

    /// Corner: Enter inside a string literal is not consumed by the smart-newline path.
    /// The dismiss code in `handleInsertNewline` still runs (popover is closed), and
    /// `textDidChange` is NOT suppressed — verified by firing a manual notification
    /// immediately after and confirming suggestions are populated.
    func test_enterKey_insideStringLiteral_notConsumedAndDismissesPopover() async throws {
        let suggestion = AutocompleteSuggestion(name: "field", typeHint: "string", kind: .string)
        let provider = MockAutocompleteProvider(stubSuggestions: [suggestion])
        let (coordinator, vm) = makeCoordinator(provider: provider)
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = NSTextView()
        textView.string = "\"hello\""
        textView.setSelectedRange(NSRange(location: 3, length: 0))

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertFalse(consumed, "Enter inside a string literal must not be consumed")
        XCTAssertFalse(vm.isVisible, "Popover must be dismissed even for the string-literal Enter path")

        // Point the textView at a JSON context where suggestions make sense, then
        // fire textDidChange to confirm the path is not suppressed.
        textView.string = "{\n  "
        textView.setSelectedRange(NSRange(location: 4, length: 0))
        let notification = Notification(name: NSText.didChangeNotification, object: textView)
        coordinator.textDidChange(notification)

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(
            vm.suggestions.isEmpty,
            "textDidChange must not be suppressed after the string-literal Enter path")
    }

    /// Corner: `applySmartInsert` guards its own `suppressTextDidChange` with `defer`;
    /// pressing Enter immediately afterwards must still schedule an autocomplete update.
    func test_enterKey_afterSmartInsert_suppressionDoesNotLeak() async throws {
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let provider = MockAutocompleteProvider(stubSuggestions: [suggestion])
        let (coordinator, vm) = makeCoordinator(provider: provider)
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")
        textView.delegate = coordinator

        // Tab — commits suggestion; applySmartInsert sets then clears suppressTextDidChange.
        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        // Move cursor to just after the inserted value (outside any string literal).
        let ns = textView.string as NSString
        let fieldRange = ns.range(of: "\"name\": \"\"")
        XCTAssertNotEqual(fieldRange.location, NSNotFound, "Field must be present after Tab commit")
        textView.setSelectedRange(NSRange(location: fieldRange.upperBound, length: 0))

        // Enter — must schedule autocomplete update; suppression must not have leaked.
        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertNewline(_:)))

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(
            vm.suggestions.isEmpty,
            "Suppression from applySmartInsert must not bleed into the next Enter press")
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

    // MARK: - Value type name after Tab

    func test_commitSelection_stringKind_publishesTypeNameInsideEmptyQuotes() async throws {
        let hint = JsonValueTypeHint(name: "string", kind: .string)
        let suggestion = AutocompleteSuggestion(name: "username", typeHint: "string", kind: .string)
        let provider = MockAutocompleteProvider(stubSuggestions: [suggestion], stubValueTypeHint: hint)
        let (coordinator, vm) = makeCoordinator(provider: provider)
        vm.suggestions = [suggestion]
        vm.isVisible = true
        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(textView.string.contains("\"username\": \"\""))
        XCTAssertFalse(textView.string.contains("string"))
        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertFalse(vm.isVisible)
    }

    func test_commitSelection_numberKind_publishesTypeNameAfterColon() async throws {
        let hint = JsonValueTypeHint(name: "int32", kind: .number)
        let suggestion = AutocompleteSuggestion(name: "count", typeHint: "int32", kind: .number)
        let provider = MockAutocompleteProvider(stubSuggestions: [suggestion], stubValueTypeHint: hint)
        let (coordinator, vm) = makeCoordinator(provider: provider)
        vm.suggestions = [suggestion]
        vm.isVisible = true
        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(textView.string.contains("\"count\": "))
        XCTAssertEqual(vm.valueTypeHint, hint)
    }

    func test_commitSelection_numberKind_drawsTypeNameAtTheCaret() async throws {
        let hint = JsonValueTypeHint(name: "int32", kind: .number)
        let suggestion = AutocompleteSuggestion(name: "count", typeHint: "int32", kind: .number)
        let provider = MockAutocompleteProvider(stubSuggestions: [suggestion], stubValueTypeHint: hint)
        let (coordinator, vm) = makeCoordinator(provider: provider)
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.string = "{\n  "
        textView.font = JsonEditorMetrics.font
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false)
        window.contentView = textView
        textView.layoutSubtreeIfNeeded()
        try textView.layoutManager?.ensureLayout(for: XCTUnwrap(textView.textContainer))

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))
        try await Task.sleep(for: .milliseconds(150))

        let label = textView.subviews.compactMap { $0 as? NSTextField }.first { $0.stringValue == "int32" }
        XCTAssertEqual(label?.isHidden, false)
        XCTAssertFalse(textView.string.contains("int32"))
        if let label {
            XCTAssertNil(label.hitTest(NSPoint(x: label.bounds.midX, y: label.bounds.midY)))
        }
    }

    func test_filledTimestamp_hidesTypeNameBeforeTheNextField() async throws {
        let hint = JsonValueTypeHint(name: "Timestamp", kind: .wktString)
        let provider = MockAutocompleteProvider(stubSuggestions: [], stubValueTypeHint: hint)
        let (coordinator, vm) = makeCoordinator(provider: provider)
        let text = "{\n  \"birthday\": \"2026-11-07T13:47:26Z\"\n  \"id\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        let cursor = (text as NSString).range(of: "\"id\"").location
        textView.setSelectedRange(NSRange(location: cursor, length: 0))

        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: textView))
    }

    func test_prettyPrintedEmptyValue_showsTypeNameWithoutCoveringTheNextField() async throws {
        let hint = JsonValueTypeHint(name: "string", kind: .string)
        let provider = MockAutocompleteProvider(stubSuggestions: [], stubValueTypeHint: hint)
        let (coordinator, _) = makeCoordinator(provider: provider)
        let text = "{\n  \"id\": \"\"\n  \"name\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        let cursor = (text as NSString).range(of: "\"\"").location + 1
        textView.setSelectedRange(NSRange(location: cursor, length: 0))

        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        try await Task.sleep(for: .milliseconds(150))

        let label = try XCTUnwrap(visibleTypeLabel(in: textView))
        let quote = (text as NSString).range(of: "\"\"").location + 1
        let quoteRect = try XCTUnwrap(glyphRect(in: textView, utf16: quote))
        let nameRect = try XCTUnwrap(glyphRect(in: textView, utf16: (text as NSString).range(of: "\"name\"").location))
        XCTAssertGreaterThanOrEqual(label.frame.minX, quoteRect.maxX - 0.5)
        XCTAssertFalse(label.frame.intersects(quoteRect))
        XCTAssertFalse(label.frame.intersects(nameRect))
    }

    func test_textChange_inlineJSON_expandsToPrettyPrintAndKeepsTheCaretInTheValue() {
        let compact = "{\"id\":\"\",\"name\":\"\"}"
        let cursor = (compact as NSString).range(of: "\"\"").location + 1
        let (coordinator, _) = makeCoordinator(formatInlineJSON: { json in
            JsonInlineDocument.pretty(json) { try JsonFormatter().format($0) }
        })
        let textView = NSTextView()
        textView.string = compact
        textView.setSelectedRange(NSRange(location: cursor, length: 0))

        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertFalse(JsonInlineDocument.isInline(textView.string))
        let caret = textView.selectedRange().location
        let ns = textView.string as NSString
        XCTAssertGreaterThan(caret, 0)
        XCTAssertLessThan(caret, ns.length)
        XCTAssertEqual(ns.character(at: caret - 1), JsonScanUTF16.quote)
        XCTAssertEqual(ns.character(at: caret), JsonScanUTF16.quote)
    }

    func test_syncDisplayedText_inlineJSON_expandsAndWritesThePrettyFormBack() {
        var text = "{\"id\":1}"
        let binding = Binding(get: { text }, set: { text = $0 })
        let editor = JSONTextEditor(
            text: binding,
            smartInsert: SmartInsertService(),
            formatInlineJSON: { json in
                JsonInlineDocument.pretty(json) { try JsonFormatter().format($0) }
            })
        let coordinator = editor.makeCoordinator()
        let textView = NSTextView()
        textView.string = text

        coordinator.syncDisplayedText(text, to: textView)

        XCTAssertEqual(textView.string, "{\n  \"id\" : 1\n}")
        XCTAssertEqual(text, "{\n  \"id\" : 1\n}")
    }

    func test_textChange_insidePrettyDocument_keepsTheOtherField() {
        let pretty = "{\n  \"id\" : \"\",\n  \"name\" : \"kept\"\n}"
        let (coordinator, _) = makeCoordinator(formatInlineJSON: { json in
            JsonInlineDocument.pretty(json) { try JsonFormatter().format($0) }
        })
        let textView = NSTextView()
        textView.string = pretty
        let cursor = (pretty as NSString).range(of: "\"\"").location + 1
        textView.setSelectedRange(NSRange(location: cursor, length: 0))
        textView.insertText("x", replacementRange: NSRange(location: cursor, length: 0))
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertTrue(textView.string.contains("\"name\" : \"kept\""), textView.string)
        XCTAssertTrue(textView.string.contains("\"id\" : \"x\""), textView.string)
    }

    func test_undo_afterInlineExpansion_restoresTheTextBeforeTheKeystroke() {
        let original = "{\"id\":1"
        let (coordinator, _) = makeCoordinator(formatInlineJSON: { json in
            JsonInlineDocument.pretty(json) { try JsonFormatter().format($0) }
        })
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 320, height: 200))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false)
        window.contentView = textView
        textView.delegate = coordinator
        textView.allowsUndo = true
        textView.string = original
        textView.setSelectedRange(NSRange(location: (original as NSString).length, length: 0))

        textView.insertText("}", replacementRange: textView.selectedRange())

        XCTAssertFalse(JsonInlineDocument.isInline(textView.string), textView.string)
        XCTAssertNotNil(window.contentView)
        textView.undoManager?.undo()
        XCTAssertEqual(textView.string, original)
    }

    func test_commitSelection_boolLiteral_replacesEmptyQuotes() {
        let suggestion = AutocompleteSuggestion(name: "true", typeHint: "bool", kind: .boolLiteral)
        let (coordinator, _) = makeCoordinator()
        let text = "{\n  \"enabled\": \"\"\n}"
        let textView = makeTextView(text: text)
        let cursor = (text as NSString).range(of: "\"\"").location + 1
        textView.setSelectedRange(NSRange(location: cursor, length: 0))

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        XCTAssertTrue(textView.string.contains("\"enabled\": true"), textView.string)
        XCTAssertFalse(textView.string.contains("\"true\""), textView.string)
    }

    func test_oneLineDocument_typeNameDoesNotCoverTheNextField() async throws {
        let hint = JsonValueTypeHint(name: "string", kind: .string)
        let provider = MockAutocompleteProvider(stubSuggestions: [], stubValueTypeHint: hint)
        let (coordinator, _) = makeCoordinator(provider: provider)
        let text = "{\"id\": \"\", \"name\": \"\"}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        let cursor = (text as NSString).range(of: "\"\"").location + 1
        textView.setSelectedRange(NSRange(location: cursor, length: 0))

        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        try await Task.sleep(for: .milliseconds(150))

        let nameRect = try XCTUnwrap(glyphRect(in: textView, utf16: (text as NSString).range(of: "\"name\"").location))
        if let label = visibleTypeLabel(in: textView) {
            XCTAssertFalse(
                label.frame.intersects(nameRect),
                "placeholder \(label.frame) covers the next field \(nameRect)")
        }
    }

    func test_wrappedLine_typeNameDoesNotCoverTheNextField() async throws {
        let hint = JsonValueTypeHint(name: "Timestamp", kind: .wktString)
        let provider = MockAutocompleteProvider(stubSuggestions: [], stubValueTypeHint: hint)
        let (coordinator, _) = makeCoordinator(provider: provider)
        let text = "{\"birthday\": \"\", \"identification\": \"\"}"
        let (textView, window) = try laidOutTextView(text, width: 140)
        XCTAssertNotNil(window.contentView)
        let cursor = (text as NSString).range(of: "\"\"").location + 1
        textView.setSelectedRange(NSRange(location: cursor, length: 0))
        let birthdayRect = try XCTUnwrap(glyphRect(
            in: textView,
            utf16: (text as NSString).range(of: "birthday").location))
        let nextRect = try XCTUnwrap(glyphRect(
            in: textView,
            utf16: (text as NSString).range(of: "identification").location))
        XCTAssertGreaterThan(nextRect.minY, birthdayRect.maxY - 1, "fixture must wrap onto the next visual line")

        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        try await Task.sleep(for: .milliseconds(150))

        if let label = visibleTypeLabel(in: textView) {
            XCTAssertFalse(
                label.frame.intersects(nextRect),
                "placeholder \(label.frame) covers the wrapped field \(nextRect)")
        }
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

    func test_commitSelection_numberKind_closingBraceAtRootIndent() {
        let suggestion = AutocompleteSuggestion(name: "count", typeHint: "int32", kind: .number)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        // Closing brace must be at column 0, not indented by the field's 2-space indent.
        XCTAssertTrue(
            textView.string.hasSuffix("\n}"),
            "Expected closing brace at column 0, got: \(textView.string.debugDescription)")
    }

    func test_commitSelection_stringKind_closingBraceAtRootIndent() {
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(
            textView.string.hasSuffix("\n}"),
            "Expected closing brace at column 0, got: \(textView.string.debugDescription)")
    }

    func test_commitSelection_messageKind_closingBraceAtRootIndent() {
        let suggestion = AutocompleteSuggestion(name: "address", typeHint: "Address", kind: .message)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(
            textView.string.hasSuffix("\n}"),
            "Expected outer closing brace at column 0, got: \(textView.string.debugDescription)")
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

    func test_commitSelection_enumFieldKind_insertsKeyWithColon() {
        let suggestion = AutocompleteSuggestion(name: "status", typeHint: "Status", kind: .enumField)
        let (coordinator, vm) = makeCoordinator()
        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = makeTextView(text: "{\n  ")

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))

        XCTAssertTrue(textView.string.contains("\"status\": "))
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

    func test_autocomplete_fieldAtDepth1_closingBraceAtColumnZero() {
        // Cursor inside root `{}` at 2-space indent → the root `}` must land at column 0.
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{\n  ")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        let result = textView.string
        XCTAssertTrue(
            result.hasSuffix("\n}"),
            "At depth 1 (cursor at 2-space indent), root closing brace must be at column 0; got: \(result)")
        XCTAssertFalse(
            result.hasSuffix("\n  }"),
            "Root closing brace must NOT have leading spaces; got: \(result)")
    }

    func test_applySmartInsert_messageKindAtDepth1_innerContentAndCloseAreIndented() {
        // `"{\n  "` → lineIndent = "  ". The .message snippet is self-contained with its own
        // 2-space closer; the outer root `}` must land at column 0.
        let suggestion = AutocompleteSuggestion(name: "nested", typeHint: "Nested", kind: .message)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{\n  ")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        let result = textView.string
        XCTAssertTrue(
            result.contains("{\n    "),
            "Inner content must be at 4-space indent (lineIndent+2); got: \(result)")
        XCTAssertTrue(
            result.contains("\n  }"),
            "Snippet's own closer must be at 2-space indent; got: \(result)")
        XCTAssertTrue(
            result.hasSuffix("\n}"),
            "Outer root closer must be at column 0; got: \(result)")
    }

    func test_applySmartInsert_messageKindAtDepth2_closingBracesAtCorrectLevels() {
        // `"{\n  \"ctx\": {\n    "` → lineIndent = "    ". The .message snippet is self-contained
        // with its own 4-space closer; the ctx `}` at 2 spaces; root `}` at column 0.
        let suggestion = AutocompleteSuggestion(name: "user", typeHint: "User", kind: .message)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{\n  \"ctx\": {\n    ")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        let result = textView.string
        XCTAssertTrue(
            result.contains("{\n      "),
            "Inner content must be at 6-space indent (lineIndent+2); got: \(result)")
        XCTAssertTrue(
            result.hasSuffix("\n}"),
            "Root closer must be at column 0; got: \(result)")
    }

    func test_autocomplete_nestedMessageAtDepth2_closingBracesHaveCorrectIndent() {
        // `"{\n  \"nested\": {\n    "` → lineIndent = "    ".
        // middle patch closes the nested `{` (opened at 2-space level) → its `}` at 2 spaces.
        // trailing patch closes the root `{` → at column 0.
        let suggestion = AutocompleteSuggestion(name: "id", typeHint: "string", kind: .string)
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: "{\n  \"nested\": {\n    ")

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        let result = textView.string
        XCTAssertTrue(
            result.contains("\n  }"),
            "Nested scope closer must have 2-space indent; got: \(result)")
        XCTAssertTrue(
            result.hasSuffix("\n}"),
            "Root closer must be at column 0; got: \(result)")
        XCTAssertFalse(
            result.hasSuffix("\n  }"),
            "Trailing (root) closer must not have leading spaces; got: \(result)")
    }

    // MARK: - wktDefault insertion inside existing `""`

    func test_commitSelection_wktDefaultKind_replacesEmptyQuotePlaceholder() {
        // Simulate: cursor is inside `"created_at": ""` right between the two quotes.
        // Text: `{\n  "created_at": ""\n}`, cursor at offset of the `|` in `"...": "|"`
        let fullText = "{\n  \"created_at\": \"\"\n}"
        // Position of the opening `"` of the value is at offset 18; cursor is at 19 (inside "").
        let cursorOffset = 19
        let suggestion = AutocompleteSuggestion(
            name: "now",
            typeHint: "Timestamp RFC 3339",
            kind: .wktDefault,
            insertValue: "2026-04-09T17:44:56Z")
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: fullText)
        textView.setSelectedRange(NSRange(location: cursorOffset, length: 0))

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        let result = textView.string
        XCTAssertTrue(
            result.contains("\"2026-04-09T17:44:56Z\""),
            "Inserted RFC 3339 value must be present; got: \(result)")
        XCTAssertFalse(
            result.contains("\"2026-04-09T17:44:56Z\"\""),
            "Dangling closing quote must not appear after inserted value; got: \(result)")
    }

    func test_commitSelection_wktDefaultKind_fromAfterColon_insertsCorrectly() {
        // Cursor is after `: ` with NO surrounding quotes — fresh insertion.
        let fullText = "{\n  \"created_at\": "
        let cursorOffset = fullText.utf16.count
        let suggestion = AutocompleteSuggestion(
            name: "now",
            typeHint: "Timestamp RFC 3339",
            kind: .wktDefault,
            insertValue: "2026-04-09T17:44:56Z")
        let (coordinator, _) = makeCoordinator()
        let textView = makeTextView(text: fullText)
        textView.setSelectedRange(NSRange(location: cursorOffset, length: 0))

        coordinator.applySmartInsert(suggestion: suggestion, to: textView)

        let result = textView.string
        XCTAssertTrue(
            result.contains("\"2026-04-09T17:44:56Z\""),
            "Inserted value must be present; got: \(result)")
        XCTAssertFalse(
            result.contains("\"2026-04-09T17:44:56Z\"\""),
            "No duplicate closing quote; got: \(result)")
    }

    // MARK: - Value type placeholder

    func test_valueTypeHint_namesItselfForVoiceOverAndUsesTheTokenColor() async throws {
        let (coordinator, _) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"name\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))

        try await publishEdit(coordinator, in: textView)

        let label = try XCTUnwrap(visibleTypeLabel(in: textView))
        XCTAssertEqual(label.stringValue, "string")
        XCTAssertEqual(label.accessibilityLabel(), "string, value type")
        XCTAssertEqual(label.accessibilityRole(), .staticText)
        XCTAssertTrue(label.isAccessibilityElement())
        XCTAssertNil(label.hitTest(NSPoint(x: label.bounds.midX, y: label.bounds.midY)))
        assertSameColor(label.textColor, JsonHighlightTheme.placeholderColor(for: .string))
        XCTAssertFalse(textView.string.contains("string"))
    }

    func test_valueTypeHint_numberStaysAtTheCaretAndBoolOpensBesideTheList() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"count\": \n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: afterColon(text), length: 0))

        try await publishEdit(coordinator, in: textView)

        let label = try XCTUnwrap(visibleTypeLabel(in: textView))
        XCTAssertEqual(label.stringValue, "int32")
        XCTAssertFalse(vm.isVisible)
        XCTAssertFalse(coordinator.autocompletePopover.isShown)
        XCTAssertFalse(textView.string.contains("int32"))
    }

    func test_valueTypeHint_boolSlot_showsTheLabelAndTheLiteralList() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"flags\": \n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: afterColon(text), length: 0))

        try await publishEdit(coordinator, in: textView)

        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "bool")
        XCTAssertEqual(vm.suggestions.map(\.name), ["true", "false"])
        XCTAssertTrue(vm.isVisible)
        XCTAssertTrue(coordinator.autocompletePopover.isShown)
    }

    func test_valueTypeHint_enumAndTimestampAndDuration_showTheNameBesideTheList() async throws {
        let provider = ValueTypeHintScenarioProvider()
        let cases: [(String, String, [String])] = [
            ("{\n  \"status\": \"\"\n}", "Status", ["ACTIVE", "INACTIVE"]),
            ("{\n  \"created_at\": \"\"\n}", "Timestamp", ["now"]),
            ("{\n  \"ttl\": \"\"\n}", "Duration", ["0s", "1s"]),
        ]
        for (text, name, suggestions) in cases {
            let (coordinator, vm) = makeCoordinator(provider: provider)
            let (textView, window) = try laidOutTextView(text, width: 420)
            XCTAssertNotNil(window.contentView)
            textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))

            try await publishEdit(coordinator, in: textView)

            XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, name, text)
            XCTAssertEqual(vm.suggestions.map(\.name), suggestions, text)
            XCTAssertTrue(coordinator.autocompletePopover.isShown, text)
        }
    }

    func test_valueTypeHint_escapeClosesTheListAndKeepsTheLabel() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"flags\": \n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: afterColon(text), length: 0))
        try await publishEdit(coordinator, in: textView)
        XCTAssertTrue(coordinator.autocompletePopover.isShown)

        let consumed = coordinator.textView(textView, doCommandBy: #selector(NSResponder.cancelOperation(_:)))

        XCTAssertTrue(consumed)
        XCTAssertFalse(vm.isVisible)
        XCTAssertFalse(coordinator.autocompletePopover.isShown)
        XCTAssertEqual(vm.valueTypeHint, JsonValueTypeHint(name: "bool", kind: .bool))
        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "bool")
    }

    func test_valueTypeHint_typingALetterHidesTheLabelAndFiltersTheList() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"status\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.delegate = coordinator
        textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))
        try await publishEdit(coordinator, in: textView)
        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "Status")

        textView.insertText("A", replacementRange: textView.selectedRange())
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertNil(visibleTypeLabel(in: textView))
        XCTAssertNil(vm.valueTypeHint)
        XCTAssertEqual(vm.suggestions.map(\.name), ["ACTIVE"])
        XCTAssertTrue(textView.string.contains("\"A\""))
    }

    func test_valueTypeHint_deletingBackToEmptyQuotes_restoresTheLabel() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"name\": \"a\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.delegate = coordinator
        textView.allowsUndo = true
        let value = (text as NSString).range(of: "\"a\"")
        textView.setSelectedRange(NSRange(location: value.location + 2, length: 0))
        try await publishEdit(coordinator, in: textView)
        XCTAssertNil(visibleTypeLabel(in: textView))

        window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: value.location + 2, length: 0))
        textView.deleteBackward(nil)
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "string")
        XCTAssertEqual(vm.valueTypeHint?.name, "string")
        XCTAssertFalse(textView.string.contains("\"a\""))
    }

    func test_valueTypeHint_spaceInsideQuotesHidesTheLabel() async throws {
        let (coordinator, _) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"name\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.delegate = coordinator
        textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))
        try await publishEdit(coordinator, in: textView)

        textView.insertText(" ", replacementRange: textView.selectedRange())
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertNil(visibleTypeLabel(in: textView))
        XCTAssertTrue(textView.string.contains("\" \""))
    }

    func test_valueTypeHint_selectionHidesTheLabelUntilTheCaretReturns() async throws {
        let (coordinator, _) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"name\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.delegate = coordinator
        let cursor = quoteCaret(in: text)
        textView.setSelectedRange(NSRange(location: cursor, length: 0))
        try await publishEdit(coordinator, in: textView)
        XCTAssertNotNil(visibleTypeLabel(in: textView))

        textView.setSelectedRange(NSRange(location: cursor, length: 2))
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertNil(visibleTypeLabel(in: textView))

        textView.setSelectedRange(NSRange(location: cursor, length: 0))
        try await Task.sleep(for: .milliseconds(150))

        let label = try XCTUnwrap(visibleTypeLabel(in: textView))
        XCTAssertEqual(label.stringValue, "string")
        XCTAssertTrue(label.isAccessibilityElement())
    }

    func test_valueTypeHint_caretMove_followsTheEmptySlotAndChangesTheName() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"name\": \"\",\n  \"count\": \n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.delegate = coordinator
        textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))
        try await publishEdit(coordinator, in: textView)
        let stringLabel = try XCTUnwrap(visibleTypeLabel(in: textView))
        XCTAssertEqual(stringLabel.stringValue, "string")
        let stringFrame = stringLabel.frame
        let count = (text as NSString).range(of: "\"count\": ")
        textView.setSelectedRange(NSRange(location: count.location + count.length, length: 0))
        try await Task.sleep(for: .milliseconds(150))

        let numberLabel = try XCTUnwrap(visibleTypeLabel(in: textView))
        XCTAssertEqual(numberLabel.stringValue, "int32")
        XCTAssertFalse(numberLabel.frame.equalTo(stringFrame))
        XCTAssertFalse(vm.isVisible)
    }

    func test_commitSelection_boolField_opensTrueAndFalseBesideTheTypeName() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        vm.suggestions = [AutocompleteSuggestion(name: "flags", typeHint: "bool", kind: .bool)]
        vm.isVisible = true
        let (textView, window) = try laidOutTextView("{\n  ", width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))
        try await Task.sleep(for: .milliseconds(400))

        XCTAssertTrue(textView.string.contains("\"flags\": "), textView.string)
        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "bool")
        XCTAssertEqual(vm.suggestions.map(\.name), ["true", "false"])
        XCTAssertTrue(coordinator.autocompletePopover.isShown)
        XCTAssertFalse(textView.string.contains("bool"))
    }

    func test_commitSelection_boolLiteral_hidesTheTypeName() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"flags\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))
        vm.suggestions = [AutocompleteSuggestion(name: "true", typeHint: "bool", kind: .boolLiteral)]
        vm.selectedIndex = 0
        vm.isVisible = true

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertTrue(textView.string.contains("\"flags\": true"), textView.string)
        XCTAssertFalse(textView.string.contains("\"true\""), textView.string)
        XCTAssertNil(vm.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: textView))
        XCTAssertFalse(coordinator.autocompletePopover.isShown)
    }

    func test_commitSelection_enumValue_hidesTheTypeName() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"status\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))
        vm.suggestions = [AutocompleteSuggestion(name: "ACTIVE", typeHint: "Status", kind: .enum)]
        vm.selectedIndex = 0
        vm.isVisible = true

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertTrue(textView.string.contains("\"ACTIVE\""), textView.string)
        XCTAssertNil(vm.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: textView))
    }

    func test_commitSelection_timestampPreset_hidesTheTypeName() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"created_at\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))
        vm.suggestions = [
            AutocompleteSuggestion(
                name: "now",
                typeHint: "Timestamp RFC 3339",
                kind: .wktDefault,
                insertValue: "2026-11-07T13:47:26Z"),
        ]
        vm.selectedIndex = 0
        vm.isVisible = true

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertTrue(textView.string.contains("\"2026-11-07T13:47:26Z\""), textView.string)
        XCTAssertNil(vm.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: textView))
    }

    func test_commitSelection_message_hidesTheTypeNameAndOpensNestedFields() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        vm.suggestions = [AutocompleteSuggestion(name: "settings", typeHint: "Settings", kind: .message)]
        vm.isVisible = true
        let (textView, window) = try laidOutTextView("{\n  ", width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertTrue(textView.string.contains("\"settings\": {"), textView.string)
        XCTAssertNil(vm.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: textView))
        XCTAssertEqual(vm.suggestions.map(\.name), ["enabled"])
        XCTAssertTrue(coordinator.autocompletePopover.isShown)
    }

    func test_commitSelection_repeatedField_replacesTheArrayNameWithTheElementName() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        vm.suggestions = [AutocompleteSuggestion(name: "labels", typeHint: "string[]", kind: .repeated)]
        vm.isVisible = true
        let (textView, window) = try laidOutTextView("{\n  ", width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))

        _ = coordinator.textView(textView, doCommandBy: #selector(NSTextView.insertTab(_:)))
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertTrue(textView.string.contains("\"labels\": []"), textView.string)
        let label = try XCTUnwrap(visibleTypeLabel(in: textView))
        XCTAssertEqual(label.stringValue, "string")
        XCTAssertFalse(vm.isVisible)
        let bracket = (textView.string as NSString).range(of: "]").location
        let bracketRect = try XCTUnwrap(glyphRect(in: textView, utf16: bracket))
        XCTAssertGreaterThanOrEqual(label.frame.minX, bracketRect.maxX - 0.5)
        XCTAssertFalse(label.frame.intersects(bracketRect))
    }

    func test_valueTypeHint_repeatedFieldBeforeBrackets_showsTheArrayName() async throws {
        let (coordinator, _) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"labels\": \n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: afterColon(text), length: 0))

        try await publishEdit(coordinator, in: textView)

        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "string[]")
        XCTAssertFalse(textView.string.contains("string[]"))
    }

    func test_valueTypeHint_mapShowsMapUntilTheCaretEntersTheObject() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let before = "{\n  \"attrs\": \n}"
        let (textView, window) = try laidOutTextView(before, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: afterColon(before), length: 0))
        try await publishEdit(coordinator, in: textView)
        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "map")

        let inside = "{\n  \"attrs\": {\n  \n}\n}"
        textView.string = inside
        let cursor = (inside as NSString).range(of: "{\n  \n}").location + 1
        textView.setSelectedRange(NSRange(location: cursor, length: 0))
        try await publishEdit(coordinator, in: textView)

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: textView))
        XCTAssertEqual(vm.suggestions.map(\.name), ["key"])
        XCTAssertTrue(coordinator.autocompletePopover.isShown)
    }

    func test_valueTypeHint_insideEmptyObject_hidesTheLabel() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"settings\": {}\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: (text as NSString).range(of: "{}").location + 1, length: 0))

        try await publishEdit(coordinator, in: textView)

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: textView))
        XCTAssertEqual(vm.suggestions.map(\.name), ["enabled"])
    }

    func test_valueTypeHint_withoutAWindow_publishesTheNameButDrawsNothing() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let textView = NSTextView()
        let text = "{\n  \"name\": \"\"\n}"
        textView.string = text
        textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))

        try await publishEdit(coordinator, in: textView)

        XCTAssertEqual(vm.valueTypeHint, JsonValueTypeHint(name: "string", kind: .string))
        XCTAssertNil(visibleTypeLabel(in: textView))
        XCTAssertFalse(coordinator.autocompletePopover.isShown)
    }

    func test_valueTypeHint_outsideTheRootAndWithoutASchema_drawsNothing() async throws {
        let provider = ValueTypeHintScenarioProvider()
        let outside = "{\"name\": \"a\"}"
        let (coordinator, vm) = makeCoordinator(provider: provider)
        let (textView, window) = try laidOutTextView(outside, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: (outside as NSString).length, length: 0))
        try await publishEdit(coordinator, in: textView)
        XCTAssertNil(vm.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: textView))

        let (noProto, noProtoModel) = makeCoordinator(provider: provider, includeProtoFile: false)
        let empty = "{\n  \"name\": \"\"\n}"
        let (protoView, protoWindow) = try laidOutTextView(empty, width: 420)
        XCTAssertNotNil(protoWindow.contentView)
        protoView.setSelectedRange(NSRange(location: quoteCaret(in: empty), length: 0))
        try await publishEdit(noProto, in: protoView)
        XCTAssertNil(noProtoModel.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: protoView))

        let metadata = makeMetadataCoordinator()
        let (metadataView, metadataWindow) = try laidOutTextView(empty, width: 420)
        XCTAssertNotNil(metadataWindow.contentView)
        metadataView.setSelectedRange(NSRange(location: quoteCaret(in: empty), length: 0))
        try await publishEdit(metadata, in: metadataView)
        XCTAssertNil(visibleTypeLabel(in: metadataView))
    }

    func test_valueTypeHint_arrayRoot_drawsNothing() async throws {
        let (coordinator, vm) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "[\"\"]"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        try await publishEdit(coordinator, in: textView)

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: textView))
    }

    func test_valueTypeHint_incompleteJSON_staysInlineAndDrawsAtTheCaret() async throws {
        let text = "{\n  \"count\": "
        let (coordinator, _) = makeCoordinator(
            provider: ValueTypeHintScenarioProvider(),
            formatInlineJSON: { json in
                JsonInlineDocument.pretty(json) { try JsonFormatter().format($0) }
            })
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))

        try await publishEdit(coordinator, in: textView)

        XCTAssertEqual(textView.string, text)
        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "int32")
    }

    func test_valueTypeHint_completingInlineJSON_drawsAfterTheCommaOfTheEmptyValue() async throws {
        let compact = "{\"name\":\"\",\"count\":1}"
        let cursor = (compact as NSString).range(of: "\"\"").location + 1
        let (coordinator, _) = makeCoordinator(
            provider: ValueTypeHintScenarioProvider(),
            formatInlineJSON: { json in
                JsonInlineDocument.pretty(json) { try JsonFormatter().format($0) }
            })
        let (textView, window) = try laidOutTextView(compact, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: cursor, length: 0))

        try await publishEdit(coordinator, in: textView)

        XCTAssertFalse(JsonInlineDocument.isInline(textView.string))
        let name = try XCTUnwrap(textView.string.range(of: "name"))
        let count = try XCTUnwrap(textView.string.range(of: "count"))
        XCTAssertLessThan(name.lowerBound, count.lowerBound)
        let label = try XCTUnwrap(visibleTypeLabel(in: textView))
        XCTAssertEqual(label.stringValue, "string")
        let comma = (textView.string as NSString).range(of: ",").location
        let commaRect = try XCTUnwrap(glyphRect(in: textView, utf16: comma))
        XCTAssertGreaterThanOrEqual(label.frame.minX, commaRect.maxX - 0.5)
        XCTAssertFalse(textView.string.contains("string"))
    }

    func test_valueTypeHint_alreadyPrettyText_keepsTheLabelWhereItIs() async throws {
        let text = "{\n  \"name\": \"\",\n  \"count\": 1\n}"
        let (coordinator, _) = makeCoordinator(
            provider: ValueTypeHintScenarioProvider(),
            formatInlineJSON: { json in
                JsonInlineDocument.pretty(json) { try JsonFormatter().format($0) }
            })
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))
        try await publishEdit(coordinator, in: textView)
        let before = try XCTUnwrap(visibleTypeLabel(in: textView)).frame
        let beforeText = textView.string

        try await publishEdit(coordinator, in: textView)

        XCTAssertEqual(textView.string, beforeText)
        let after = try XCTUnwrap(visibleTypeLabel(in: textView)).frame
        XCTAssertEqual(after.minX, before.minX, accuracy: 0.5)
        XCTAssertEqual(after.minY, before.minY, accuracy: 0.5)
    }

    func test_externalDocumentReplace_recomputesTheTypeNameAtTheNewCaret() async throws {
        let sorted = try JsonFormatter().format("{\"name\":\"\",\"count\":1}")
        let count = try XCTUnwrap(sorted.range(of: "\"count\""))
        let name = try XCTUnwrap(sorted.range(of: "\"name\""))
        XCTAssertLessThan(count.lowerBound, name.lowerBound)
        let compact = "{\"name\":\"\",\"count\":1}"
        let (coordinator, vm) = makeCoordinator(
            provider: ValueTypeHintScenarioProvider(),
            formatInlineJSON: { json in
                JsonInlineDocument.pretty(json) { try JsonFormatter().format($0) }
            })
        let (textView, window) = try laidOutTextView(compact, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.setSelectedRange(NSRange(location: quoteCaret(in: compact), length: 0))

        coordinator.syncDisplayedText(compact, to: textView)
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertFalse(JsonInlineDocument.isInline(textView.string))
        XCTAssertLessThan(
            try XCTUnwrap(textView.string.range(of: "name")).lowerBound,
            try XCTUnwrap(textView.string.range(of: "count")).lowerBound)
        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "string")
        XCTAssertEqual(vm.valueTypeHint?.name, "string")
        XCTAssertFalse(textView.string.contains("string"))

        let filled = "{\n  \"name\": \"Ada\"\n}"
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        coordinator.syncDisplayedText(filled, to: textView)
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertEqual(textView.string, filled)
        XCTAssertNil(vm.valueTypeHint)
        XCTAssertNil(visibleTypeLabel(in: textView))
    }

    func test_valueTypeHint_narrowLine_hidesInsteadOfWideningTheDocument() async throws {
        let (coordinator, _) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"name\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        let quote = quoteCaret(in: text)
        let quoteRect = try XCTUnwrap(glyphRect(in: textView, utf16: quote))
        let tightWidth = quoteRect.maxX + 8
        textView.frame.size.width = tightWidth
        textView.textContainer?.containerSize = NSSize(width: tightWidth, height: .greatestFiniteMagnitude)
        textView.layoutSubtreeIfNeeded()
        try textView.layoutManager?.ensureLayout(for: XCTUnwrap(textView.textContainer))
        textView.setSelectedRange(NSRange(location: quote, length: 0))

        try await publishEdit(coordinator, in: textView)

        XCTAssertNil(visibleTypeLabel(in: textView))
        XCTAssertEqual(textView.frame.width, tightWidth, accuracy: 0.5)
        XCTAssertFalse(textView.isHorizontallyResizable)
        XCTAssertFalse(textView.string.contains("string"))
    }

    func test_undoAndRedo_redrawTheTypeNameForTheRestoredCaret() async throws {
        let (coordinator, _) = makeCoordinator(provider: ValueTypeHintScenarioProvider())
        let text = "{\n  \"name\": \"\"\n}"
        let (textView, window) = try laidOutTextView(text, width: 420)
        XCTAssertNotNil(window.contentView)
        textView.delegate = coordinator
        textView.allowsUndo = true
        textView.setSelectedRange(NSRange(location: quoteCaret(in: text), length: 0))
        try await publishEdit(coordinator, in: textView)
        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "string")
        let undoBeforeTyping = textView.undoManager
        undoBeforeTyping?.undo()
        XCTAssertEqual(textView.string, text)

        textView.insertText("a", replacementRange: textView.selectedRange())
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertNil(visibleTypeLabel(in: textView))
        XCTAssertFalse(textView.string.contains("string"))

        textView.undoManager?.undo()
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertFalse(textView.string.contains("\"a\""), textView.string)
        XCTAssertEqual(visibleTypeLabel(in: textView)?.stringValue, "string")
        XCTAssertFalse(textView.string.contains("string"))

        textView.undoManager?.redo()
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertTrue(textView.string.contains("\"a\""), textView.string)
        XCTAssertNil(visibleTypeLabel(in: textView))
    }

    private func quoteCaret(in text: String) -> Int {
        (text as NSString).range(of: "\"\"").location + 1
    }

    private func afterColon(_ text: String) -> Int {
        let colon = (text as NSString).range(of: ": ")
        return colon.location + colon.length
    }

    private func assertSameColor(_ actual: NSColor?, _ expected: NSColor, line: UInt = #line) {
        let left = (actual ?? .clear).usingColorSpace(.sRGB) ?? .clear
        let right = expected.usingColorSpace(.sRGB) ?? expected
        XCTAssertEqual(left.redComponent, right.redComponent, accuracy: 0.02, line: line)
        XCTAssertEqual(left.greenComponent, right.greenComponent, accuracy: 0.02, line: line)
        XCTAssertEqual(left.blueComponent, right.blueComponent, accuracy: 0.02, line: line)
        XCTAssertEqual(left.alphaComponent, right.alphaComponent, accuracy: 0.02, line: line)
    }
}

/// Schema stand-in for the request-body type name. Names follow the proto placeholder rules.
private struct ValueTypeHintScenarioProvider: AutocompleteProviderProtocol {
    func suggestions(
        for context: AutocompleteContext,
        rootMessageType _: String,
        in _: ProtoFile)
        -> [AutocompleteSuggestion]
    {
        switch context.mode {
        case .key:
            if context.resolvedPath == ["settings"] {
                return [AutocompleteSuggestion(name: "enabled", typeHint: "bool", kind: .bool)]
            }
            if context.resolvedPath == ["attrs"] {
                return [AutocompleteSuggestion(name: "key", typeHint: "string", kind: .string)]
            }
            return [
                AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string),
                AutocompleteSuggestion(name: "count", typeHint: "int32", kind: .number),
                AutocompleteSuggestion(name: "settings", typeHint: "Settings", kind: .message),
                AutocompleteSuggestion(name: "status", typeHint: "Status", kind: .enumField),
                AutocompleteSuggestion(name: "labels", typeHint: "string[]", kind: .repeated),
                AutocompleteSuggestion(name: "created_at", typeHint: "Timestamp", kind: .wktString),
                AutocompleteSuggestion(name: "ttl", typeHint: "Duration", kind: .wktString),
                AutocompleteSuggestion(name: "flags", typeHint: "bool", kind: .bool),
                AutocompleteSuggestion(name: "attrs", typeHint: "map", kind: .message),
            ]

        case .enumValue:
            switch context.currentFieldKey {
            case "status":
                return [
                    AutocompleteSuggestion(name: "ACTIVE", typeHint: "Status", kind: .enum),
                    AutocompleteSuggestion(name: "INACTIVE", typeHint: "Status", kind: .enum),
                ]

            case "created_at":
                return [
                    AutocompleteSuggestion(
                        name: "now",
                        typeHint: "Timestamp RFC 3339",
                        kind: .wktDefault,
                        insertValue: "2026-11-07T13:47:26Z"),
                ]

            case "ttl":
                return [
                    AutocompleteSuggestion(name: "0s", typeHint: "Duration", kind: .wktDefault, insertValue: "0s"),
                    AutocompleteSuggestion(name: "1s", typeHint: "Duration", kind: .wktDefault, insertValue: "1s"),
                ]

            case "flags":
                return [
                    AutocompleteSuggestion(name: "true", typeHint: "bool", kind: .boolLiteral),
                    AutocompleteSuggestion(name: "false", typeHint: "bool", kind: .boolLiteral),
                ]

            default:
                return []
            }

        case .arrayElement:
            guard context.resolvedPath == ["flags"] else { return [] }

            return [
                AutocompleteSuggestion(name: "true", typeHint: "bool", kind: .boolLiteral),
                AutocompleteSuggestion(name: "false", typeHint: "bool", kind: .boolLiteral),
            ]
        }
    }

    func valueTypeHint(
        for context: AutocompleteContext,
        rootMessageType _: String,
        in _: ProtoFile)
        -> JsonValueTypeHint?
    {
        switch context.mode {
        case .key:
            return nil

        case .enumValue:
            switch context.currentFieldKey {
            case "name":
                return JsonValueTypeHint(name: "string", kind: .string)
            case "count":
                return JsonValueTypeHint(name: "int32", kind: .number)
            case "settings":
                return JsonValueTypeHint(name: "Settings", kind: .message)
            case "status":
                return JsonValueTypeHint(name: "Status", kind: .enumField)
            case "labels":
                return JsonValueTypeHint(name: "string[]", kind: .repeated)
            case "created_at":
                return JsonValueTypeHint(name: "Timestamp", kind: .wktString)
            case "ttl":
                return JsonValueTypeHint(name: "Duration", kind: .wktString)
            case "flags":
                return JsonValueTypeHint(name: "bool", kind: .bool)
            case "attrs":
                return JsonValueTypeHint(name: "map", kind: .message)
            default:
                return nil
            }

        case .arrayElement:
            if context.resolvedPath == ["labels"] {
                return JsonValueTypeHint(name: "string", kind: .string)
            }
            if context.resolvedPath == ["flags"] {
                return JsonValueTypeHint(name: "bool", kind: .bool)
            }
            return nil
        }
    }
}
