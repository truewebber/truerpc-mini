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
        let vm = AutocompleteViewModel(provider: provider, resolver: resolver)
        let resolvedProtoFile = protoFile ?? makeProtoFile()
        var text = ""
        let binding = Binding(get: { text }, set: { text = $0 })
        let editor = JSONTextEditor(
            text: binding,
            autocompleteViewModel: vm,
            protoFile: resolvedProtoFile)
        return (editor.makeCoordinator(), vm)
    }

    // MARK: - test_textChange_triggersAutocompleteViewModelTextDidChange

    func test_textChange_triggersAutocompleteViewModelTextDidChange() async throws {
        let suggestion = AutocompleteSuggestion(name: "userId", typeHint: "int64", kind: .number)
        let provider = MockAutocompleteProvider(stubSuggestions: [suggestion])
        let (coordinator, vm) = makeCoordinator(provider: provider)

        let textView = NSTextView()
        textView.string = "{ "

        let notification = Notification(name: NSText.didChangeNotification, object: textView)
        coordinator.textDidChange(notification)

        // Allow async task inside textDidChange to complete
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertFalse(vm.suggestions.isEmpty, "AutocompleteViewModel must receive suggestions after textDidChange")
        XCTAssertTrue(vm.isVisible, "Popover must be visible when suggestions are available")
    }

    // MARK: - test_commitSelection_stringKind_insertsFormattedText

    func test_commitSelection_stringKind_insertsFormattedText() {
        let suggestion = AutocompleteSuggestion(name: "username", typeHint: "string", kind: .string)
        let (coordinator, vm) = makeCoordinator()

        vm.suggestions = [suggestion]
        vm.isVisible = true

        let textView = NSTextView()
        textView.string = "{\n  "
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))

        let consumed = coordinator.textView(
            textView,
            doCommandBy: #selector(NSTextView.insertNewline(_:)))

        XCTAssertTrue(consumed, "Enter key must be consumed when popover is visible")
        XCTAssertTrue(
            textView.string.contains("\"username\": \"\""),
            "String-kind commit must insert formatted text with empty quoted value")
    }

    // MARK: - test_escapeKey_dismissesPopover

    func test_escapeKey_dismissesPopover() {
        let (coordinator, vm) = makeCoordinator()

        vm.suggestions = [AutocompleteSuggestion(name: "field", typeHint: "string", kind: .string)]
        vm.isVisible = true

        let textView = NSTextView()
        let consumed = coordinator.textView(
            textView,
            doCommandBy: #selector(NSResponder.cancelOperation(_:)))

        XCTAssertTrue(consumed, "Esc key must be consumed when popover is visible")
        XCTAssertFalse(vm.isVisible, "Popover must be dismissed after Esc")
    }
}
