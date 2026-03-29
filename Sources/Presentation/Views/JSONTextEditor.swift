import AppKit
import SwiftUI

/// Custom text editor for JSON with smart quotes disabled.
/// When `autocompleteViewModel` and `protoFile` are provided the editor hooks
/// into the autocomplete pipeline: it calls the view-model on every keystroke
/// and hosts an `NSPopover` (anchored at the text cursor) that shows suggestions.
struct JSONTextEditor: NSViewRepresentable {
    @Binding var text: String
    var autocompleteViewModel: AutocompleteViewModel?
    var protoFile: ProtoFile?

    init(
        text: Binding<String>,
        autocompleteViewModel: AutocompleteViewModel? = nil,
        protoFile: ProtoFile? = nil)
    {
        _text = text
        self.autocompleteViewModel = autocompleteViewModel
        self.protoFile = protoFile
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        textView.setAccessibilityIdentifier("json_editor")
        textView.delegate = context.coordinator
        textView.string = text
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context _: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JSONTextEditor
        weak var textView: NSTextView?

        /// Tracks the most recent pending context-update task spawned after a text change.
        /// Cancelled on explicit suggestion commit or Escape so the popover is not re-opened
        /// by a stale task after an intentional dismiss.
        private var pendingUpdateTask: Task<Void, Never>?

        /// Suppresses autocomplete re-trigger while smart-insert modifies the text view.
        private var suppressTextDidChange = false

        private let smartInsert = SmartInsertService()

        init(_ parent: JSONTextEditor) {
            self.parent = parent
        }

        /// Single NSPopover instance owned by this coordinator.
        /// .applicationDefined prevents AppKit from auto-closing it on the next keystroke.
        lazy var autocompletePopover: NSPopover = {
            let popover = NSPopover()
            popover.behavior = .applicationDefined
            popover.animates = false
            if let vm = parent.autocompleteViewModel {
                let hostingController = NSHostingController(
                    rootView: AutocompletePopoverView(
                        viewModel: vm,
                        onRowTapped: { [weak self] suggestion in
                            self?.commitSuggestion(suggestion, vm: vm)
                        },
                        onEscape: { [weak self] in
                            self?.pendingUpdateTask?.cancel()
                            vm.dismiss()
                            self?.autocompletePopover.close()
                        }))
                hostingController.view.setAccessibilityIdentifier("autocomplete_popover")
                popover.contentViewController = hostingController
            }
            return popover
        }()

        // MARK: NSTextViewDelegate — text changes

        nonisolated func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            MainActor.assumeIsolated {
                let text = textView.string
                parent.text = text

                guard !suppressTextDidChange else { return }

                let cursorOffset = textView.selectedRange().location

                guard let vm = parent.autocompleteViewModel,
                      let protoFile = parent.protoFile
                else { return }

                pendingUpdateTask?.cancel()
                pendingUpdateTask = Task { @MainActor [weak textView] in
                    await vm.textDidChange(text, cursorOffset: cursorOffset, protoFile: protoFile)
                    guard !Task.isCancelled else { return }
                    guard let textView else { return }

                    if vm.isVisible {
                        self.showPopoverIfNeeded(in: textView)
                    } else {
                        self.autocompletePopover.close()
                    }
                }
            }
        }

        // MARK: NSTextViewDelegate — keyboard commands

        nonisolated func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector)
            -> Bool
        {
            MainActor.assumeIsolated {
                guard let vm = parent.autocompleteViewModel, vm.isVisible else { return false }

                switch commandSelector {
                case #selector(NSTextView.moveUp(_:)):
                    vm.moveUp()
                    return true

                case #selector(NSTextView.moveDown(_:)):
                    vm.moveDown()
                    return true

                case #selector(NSTextView.insertTab(_:)):
                    guard let suggestion = vm.commitSelection() else { return false }

                    if suggestion.kind == .fillDefaults {
                        pendingUpdateTask?.cancel()
                        Task { await vm.fillDefaultsHandler?() }
                        vm.dismiss()
                        autocompletePopover.close()
                        return true
                    }

                    applySmartInsert(suggestion: suggestion, to: textView)
                    postInsertUpdate(suggestion: suggestion, textView: textView, vm: vm)
                    return true

                case #selector(NSTextView.insertNewline(_:)):
                    pendingUpdateTask?.cancel()
                    vm.dismiss()
                    autocompletePopover.close()
                    suppressTextDidChange = true
                    DispatchQueue.main.async { self.suppressTextDidChange = false }
                    return false

                case #selector(NSResponder.cancelOperation(_:)):
                    pendingUpdateTask?.cancel()
                    vm.dismiss()
                    autocompletePopover.close()
                    return true

                default:
                    return false
                }
            }
        }

        // MARK: - Suggestion commit (keyboard + mouse)

        /// Commits a suggestion received from the popover (mouse click or popover keyboard shortcut).
        /// Handles both `fillDefaults` (triggers `resetToPreset`) and regular insertions.
        private func commitSuggestion(_ suggestion: AutocompleteSuggestion, vm: AutocompleteViewModel) {
            if suggestion.kind == .fillDefaults {
                pendingUpdateTask?.cancel()
                Task { await vm.fillDefaultsHandler?() }
                vm.dismiss()
                autocompletePopover.close()
                return
            }

            guard let tv = textView else { return }

            applySmartInsert(suggestion: suggestion, to: tv)
            postInsertUpdate(suggestion: suggestion, textView: tv, vm: vm)
        }

        /// After inserting a suggestion, either re-trigger autocomplete (for compound types
        /// where the cursor lands inside `{}` or `[]`) or dismiss the popover.
        private func postInsertUpdate(
            suggestion: AutocompleteSuggestion,
            textView: NSTextView,
            vm: AutocompleteViewModel)
        {
            let continueAutocomplete = suggestion.kind == .message || suggestion.kind == .repeated

            if continueAutocomplete, let protoFile = parent.protoFile {
                let newText = textView.string
                let offset = textView.selectedRange().location
                pendingUpdateTask?.cancel()
                pendingUpdateTask = Task { @MainActor [weak textView] in
                    await vm.textDidChange(newText, cursorOffset: offset, protoFile: protoFile)
                    guard !Task.isCancelled else { return }
                    guard let textView else { return }

                    if vm.isVisible {
                        self.showPopoverIfNeeded(in: textView)
                    } else {
                        self.autocompletePopover.close()
                    }
                }
            } else {
                pendingUpdateTask?.cancel()
                vm.dismiss()
                autocompletePopover.close()
            }
        }

        // MARK: - Popover positioning

        private func showPopoverIfNeeded(in textView: NSTextView) {
            guard let window = textView.window else { return }

            let range = textView.selectedRange()
            let rect = cursorViewRect(in: textView, range: range, window: window)

            if autocompletePopover.isShown {
                autocompletePopover.close()
            }
            autocompletePopover.show(relativeTo: rect, of: textView, preferredEdge: .maxY)
            window.makeFirstResponder(textView)
        }

        private func cursorViewRect(
            in textView: NSTextView,
            range: NSRange,
            window: NSWindow)
            -> NSRect
        {
            // Screen coords → window space → textView local space
            let screenRect = textView.firstRect(forCharacterRange: range, actualRange: nil)
            let windowRect = window.convertFromScreen(screenRect)
            return textView.convert(windowRect, from: nil)
        }

        // MARK: - Smart insert

        /// Applies a replacement without querying `shouldChangeText`, which can reject programmatic
        /// auto-closing edits in headless `NSTextView` instances (e.g. integration tests).
        private static func replaceInTextViewWithoutShouldChangeGate(
            _ textView: NSTextView,
            range: NSRange,
            string: String)
        {
            guard let storage = textView.textStorage else {
                textView.replaceCharacters(in: range, with: string)
                textView.didChangeText()
                return
            }

            storage.beginEditing()
            storage.replaceCharacters(in: range, with: string)
            storage.endEditing()
            textView.didChangeText()
        }

        /// Internal for `@testable` integration tests (keyboard path also calls this).
        func applySmartInsert(suggestion: AutocompleteSuggestion, to textView: NSTextView) {
            let (insertText, cursorBack) = smartInsert.smartInsertComponents(for: suggestion)
            guard !insertText.isEmpty else { return }

            var range = textView.selectedRange()
            // When cursor is inside a partial string (e.g. `"nam`) or after bare text
            // (e.g. `{dfdf`), extend the replacement range back to the start of that
            // partial token so the snippet replaces it rather than being appended.
            let ns = textView.string as NSString
            if let partialStart = smartInsert.findPartialStringStart(in: ns, cursorOffset: range.location) {
                range = NSRange(location: partialStart, length: range.location - partialStart)
            } else if let bareStart = smartInsert.findBareTextStart(in: ns, cursorOffset: range.location) {
                range = NSRange(location: bareStart, length: range.location - bareStart)
            }
            if textView.shouldChangeText(in: range, replacementString: insertText) {
                suppressTextDidChange = true
                defer { suppressTextDidChange = false }

                let lengthBefore = (textView.string as NSString).length
                textView.replaceCharacters(in: range, with: insertText)
                textView.didChangeText()
                let lengthAfter = (textView.string as NSString).length
                // Use the actual UTF-16 length delta — `NSTextView` may normalize newlines/quotes so
                // `insertText.utf16.count` does not match what was stored (breaks bracket math in tests
                // and edge cases).
                let insertedUTF16Count = lengthAfter - lengthBefore + range.length
                let insertEnd = range.location + insertedUTF16Count
                let nsFull = textView.string as NSString
                let pendingArrays = smartInsert.arrayBracketBalanceInPrefix(ns: nsFull, endUTF16: insertEnd)
                let nextSig = smartInsert.nextSignificantUTF16IndexAndScalar(ns: nsFull, fromUTF16: insertEnd)
                let lineIndent = smartInsert.lineIndentation(in: nsFull, at: range.location)

                if pendingArrays > 0,
                   let next = nextSig,
                   next.scalar == JsonScanUTF16.bracketClose,
                   let closeBracket = smartInsert.indexOfClosingBracketForContainingArray(
                       ns: nsFull, fromUTF16: insertEnd),
                   next.index == closeBracket,
                   let openBracket = smartInsert.indexOfMatchingOpenBracket(
                       ns: nsFull, closingBracketUTF16: closeBracket)
                {
                    let innerBraces = smartInsert.netBraceCountInUTF16Range(
                        ns: nsFull,
                        fromUTF16: openBracket + 1,
                        toUTF16: insertEnd)
                    if innerBraces > 0 {
                        let patch = smartInsert.indentedClosingSuffix(count: innerBraces, baseIndent: lineIndent)
                        // Close the object(s) immediately after the new field — not before `]`, or
                        // whitespace between the value and `]` ends up *inside* the closing brace
                        // (e.g. `"id": ""\n  \n}]` instead of `"id": ""\n}\n  ]`).
                        Self.replaceInTextViewWithoutShouldChangeGate(
                            textView,
                            range: NSRange(location: insertEnd, length: 0),
                            string: patch)
                    }
                } else {
                    let missingMiddle = smartInsert.unclosedBraceCount(in: textView.string)
                    let skipMiddleInsertion = nextSig.map { pair in
                        pair.scalar == JsonScanUTF16.comma || pair.scalar == JsonScanUTF16.colon
                    } ?? false
                    if !skipMiddleInsertion, missingMiddle > 1 {
                        let patch = smartInsert.indentedClosingSuffix(count: missingMiddle - 1, baseIndent: lineIndent)
                        Self.replaceInTextViewWithoutShouldChangeGate(
                            textView,
                            range: NSRange(location: insertEnd, length: 0),
                            string: patch)
                    }
                }

                let cursorPos = insertEnd - cursorBack

                let missingTrailing = smartInsert.unclosedBraceCount(in: textView.string)
                if missingTrailing == 1 {
                    let suffix = smartInsert.indentedClosingSuffix(count: 1, baseIndent: lineIndent)
                    let endRange = NSRange(location: textView.string.utf16.count, length: 0)
                    Self.replaceInTextViewWithoutShouldChangeGate(textView, range: endRange, string: suffix)
                }

                parent.text = textView.string
                textView.setSelectedRange(NSRange(location: max(0, cursorPos), length: 0))
            }
        }
    }
}
