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
    var smartInsert: any SmartInsertServiceProtocol
    /// Turns a valid inline document into pretty JSON. `nil` leaves the text unchanged.
    var formatInlineJSON: ((String) -> String?)?

    init(
        text: Binding<String>,
        autocompleteViewModel: AutocompleteViewModel? = nil,
        protoFile: ProtoFile? = nil,
        smartInsert: any SmartInsertServiceProtocol,
        formatInlineJSON: ((String) -> String?)? = nil)
    {
        _text = text
        self.autocompleteViewModel = autocompleteViewModel
        self.protoFile = protoFile
        self.smartInsert = smartInsert
        self.formatInlineJSON = formatInlineJSON
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        textView.font = JsonEditorMetrics.font
        textView.defaultParagraphStyle = JsonEditorMetrics.paragraphStyle
        textView.typingAttributes = JsonEditorMetrics.storageAttributes
        textView.textContainerInset = JsonEditorMetrics.textInset
        textView.textContainer?.lineFragmentPadding = JsonEditorMetrics.lineFragmentPadding
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.allowsUndo = true

        textView.setAccessibilityIdentifier("json_editor")
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        context.coordinator.syncDisplayedText(text, to: textView)
        context.coordinator.applyStyle(to: textView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        context.coordinator.parent = self
        context.coordinator.syncDisplayedText(text, to: textView)
        context.coordinator.applyStyle(to: textView)
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

        /// Type-name refresh after a scalar insert or a caret move. Kept apart from suggestion updates.
        private var pendingHintTask: Task<Void, Never>?

        /// Suppresses autocomplete re-trigger while smart-insert modifies the text view.
        private var suppressTextDidChange = false

        /// Smart insert asks `shouldChangeText` itself. That call must not be rewritten as inline formatting.
        private var isApplyingSmartInsert = false

        /// Stops font and color updates from being treated as another edit.
        private var isApplyingStyle = false

        /// A keystroke already refreshes the type name. The selection change from that keystroke is skipped.
        private var ignoreNextSelectionChange = false

        private var smartInsert: any SmartInsertServiceProtocol {
            parent.smartInsert
        }

        private let valueTypeHintLabel = ValueTypeHintLabel()

        func applyStyle(to textView: NSTextView) {
            guard !isApplyingStyle else { return }

            isApplyingStyle = true
            defer { isApplyingStyle = false }
            JsonTextStyler.apply(to: textView)
        }

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
                hostingController.sizingOptions = .preferredContentSize
                hostingController.view.setAccessibilityIdentifier("autocomplete_popover")
                popover.contentViewController = hostingController
            }
            return popover
        }()

        // MARK: NSTextViewDelegate — text changes

        nonisolated func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            MainActor.assumeIsolated {
                guard !isApplyingStyle else { return }
                guard !suppressTextDidChange else {
                    parent.text = textView.string
                    return
                }

                publishEditedText(in: textView)
            }
        }

        /// Typing that completes a one-line document is replaced by the pretty form before AppKit records the key.
        /// One undo then restores the text from before that keystroke.
        nonisolated func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?)
            -> Bool
        {
            MainActor.assumeIsolated {
                guard !isApplyingSmartInsert, !suppressTextDidChange, !isApplyingStyle else { return true }
                guard let replacementString, parent.formatInlineJSON != nil else { return true }

                let current = textView.string as NSString
                guard affectedCharRange.location != NSNotFound,
                      affectedCharRange.location <= current.length,
                      NSMaxRange(affectedCharRange) <= current.length
                else { return true }

                let proposed = current.replacingCharacters(in: affectedCharRange, with: replacementString)
                let formatted = expandedInline(proposed)
                guard formatted != proposed else { return true }

                let cursorInProposed = affectedCharRange.location + (replacementString as NSString).length
                let caret = JsonInlineDocument.cursor(
                    in: formatted,
                    matching: proposed,
                    cursorUTF16: cursorInProposed)
                let original = String(current)
                let selection = textView.selectedRange()
                textView.undoManager?.registerUndo(withTarget: self) { coordinator in
                    MainActor.assumeIsolated {
                        coordinator.restoreUndoSnapshot(original, selection: selection, in: textView)
                    }
                }
                writeDocument(formatted, caret: caret, in: textView)
                publishEditedText(in: textView)
                return false
            }
        }

        private func publishEditedText(in textView: NSTextView) {
            ignoreNextSelectionChange = true
            DispatchQueue.main.async { @MainActor [weak self] in
                self?.ignoreNextSelectionChange = false
            }
            applyInlineFormat(to: textView)

            let text = textView.string
            let cursorOffset = textView.selectedRange().location
            parent.text = text

            if let vm = parent.autocompleteViewModel, let protoFile = parent.protoFile {
                pendingHintTask?.cancel()
                pendingUpdateTask?.cancel()
                pendingUpdateTask = Task { @MainActor [weak textView] in
                    await vm.textDidChange(text, cursorOffset: cursorOffset, protoFile: protoFile)
                    guard !Task.isCancelled else { return }
                    guard let textView else { return }

                    self.showValueTypeHint(vm.valueTypeHint, in: textView)
                    if vm.isVisible {
                        self.showPopoverIfNeeded(in: textView)
                    } else {
                        self.autocompletePopover.close()
                    }
                }
            } else {
                showValueTypeHint(nil, in: textView)
            }

            // Offscreen text views are not drawn, and painting them delays autocomplete.
            guard textView.window != nil else { return }

            isApplyingStyle = true
            JsonTextStyler.applyColors(to: textView)
            isApplyingStyle = false
        }

        /// Puts `text` back and registers the inverse so redo returns to the pretty form.
        private func restoreUndoSnapshot(_ text: String, selection: NSRange, in textView: NSTextView) {
            let current = textView.string
            let currentSelection = textView.selectedRange()
            textView.undoManager?.registerUndo(withTarget: self) { coordinator in
                MainActor.assumeIsolated {
                    coordinator.restoreUndoSnapshot(current, selection: currentSelection, in: textView)
                }
            }
            writeDocument(text, caret: selection.location, in: textView)
            let length = (textView.string as NSString).length
            let location = min(max(0, selection.location), length)
            let rangeLength = min(selection.length, max(0, length - location))
            textView.setSelectedRange(NSRange(location: location, length: rangeLength))
        }

        nonisolated func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            MainActor.assumeIsolated {
                guard !isApplyingStyle, !suppressTextDidChange else { return }

                if ignoreNextSelectionChange {
                    ignoreNextSelectionChange = false
                    return
                }
                guard let vm = parent.autocompleteViewModel else {
                    showValueTypeHint(nil, in: textView)
                    return
                }

                scheduleValueTypeHintRefresh(in: textView, vm: vm)
            }
        }

        // MARK: NSTextViewDelegate — keyboard commands

        nonisolated func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector)
            -> Bool
        {
            MainActor.assumeIsolated {
                // insertNewline is intercepted regardless of popover visibility so that
                // smart Enter-key indentation always applies (AC-6 through AC-10).
                if commandSelector == #selector(NSTextView.insertNewline(_:)) {
                    return handleInsertNewline(in: textView)
                }

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

        /// Dismisses autocomplete if visible, then delegates to `applySmartNewline`.
        /// Autocomplete dismissal on Enter preserves the existing behaviour.
        private func handleInsertNewline(in textView: NSTextView) -> Bool {
            if let vm = parent.autocompleteViewModel, vm.isVisible {
                pendingUpdateTask?.cancel()
                vm.dismiss()
                autocompletePopover.close()
            }
            return applySmartNewline(in: textView)
        }

        /// Implements the Enter-key decision tree (evaluated in order):
        ///
        /// 1. Inside string literal → pass through (return false, let NSTextView insert a plain newline).
        /// 2. Between `{}`/`[]` with only horizontal whitespace → AC-7 split.
        /// 3. Char immediately before cursor (ignoring trailing horizontal whitespace on the line)
        ///    is `{` or `[` → AC-6 indent.
        /// 4. Otherwise → same indent as current line (AC-8/AC-9).
        ///
        /// Selection is deleted first; the indent is derived from the original selection-start line.
        private func applySmartNewline(in textView: NSTextView) -> Bool {
            let selRange = textView.selectedRange()
            let ns0 = textView.string as NSString
            let checkOffset = selRange.location

            if smartInsert.isInsideStringLiteral(in: ns0, at: checkOffset) {
                return false
            }

            // Compute indent from original text before any deletion.
            let currentIndent = smartInsert.lineIndentation(in: ns0, at: checkOffset)
            let innerIndent = currentIndent + "  "

            if selRange.length > 0 {
                Self.replaceInTextViewWithoutShouldChangeGate(textView, range: selRange, string: "")
            }

            let cursorOffset = selRange.location
            let ns = textView.string as NSString

            // AC-7: cursor between matching open/close bracket pair with only horizontal whitespace.
            if let before = nonNewlineNonWhitespaceCharBefore(in: ns, cursorOffset: cursorOffset),
               let after = nonNewlineNonWhitespaceCharAfter(in: ns, cursorOffset: cursorOffset),
               isMatchingOpenClosePair(open: before.char, close: after.char)
            {
                let replaceStart = before.index + 1
                let replaceRange = NSRange(location: replaceStart, length: after.index - replaceStart)
                Self.replaceInTextViewWithoutShouldChangeGate(
                    textView,
                    range: replaceRange,
                    string: "\n\(innerIndent)\n\(currentIndent)")
                parent.text = textView.string
                textView.setSelectedRange(NSRange(location: replaceStart + 1 + innerIndent.count, length: 0))
                return true
            }

            // AC-6: char immediately before cursor (ignoring trailing horizontal whitespace) is `{` or `[`.
            if let before = nonNewlineNonWhitespaceCharBefore(in: ns, cursorOffset: cursorOffset),
               before.char == JsonScanUTF16.braceOpen || before.char == JsonScanUTF16.bracketOpen
            {
                Self.replaceInTextViewWithoutShouldChangeGate(
                    textView,
                    range: NSRange(location: cursorOffset, length: 0),
                    string: "\n\(innerIndent)")
                parent.text = textView.string
                textView.setSelectedRange(NSRange(location: cursorOffset + 1 + innerIndent.count, length: 0))
                return true
            }

            // AC-8/AC-9: same indent as current line.
            Self.replaceInTextViewWithoutShouldChangeGate(
                textView,
                range: NSRange(location: cursorOffset, length: 0),
                string: "\n\(currentIndent)")
            parent.text = textView.string
            textView.setSelectedRange(NSRange(location: cursorOffset + 1 + currentIndent.count, length: 0))
            return true
        }

        /// Scans backward from `cursorOffset`, skipping spaces and tabs but stopping at a newline.
        /// Returns the index and UTF-16 value of the first non-whitespace character found, or `nil`.
        private func nonNewlineNonWhitespaceCharBefore(
            in ns: NSString,
            cursorOffset: Int)
            -> (index: Int, char: UInt16)?
        {
            var i = cursorOffset - 1
            while i >= 0 {
                let c = ns.character(at: i)
                if c == JsonScanUTF16.lf || c == JsonScanUTF16.cr {
                    return nil
                }
                if c != JsonScanUTF16.space, c != JsonScanUTF16.tab {
                    return (i, c)
                }
                i -= 1
            }
            return nil
        }

        /// Scans forward from `cursorOffset`, skipping spaces and tabs but stopping at a newline.
        /// Returns the index and UTF-16 value of the first non-whitespace character found, or `nil`.
        private func nonNewlineNonWhitespaceCharAfter(
            in ns: NSString,
            cursorOffset: Int)
            -> (index: Int, char: UInt16)?
        {
            var i = cursorOffset
            while i < ns.length {
                let c = ns.character(at: i)
                if c == JsonScanUTF16.lf || c == JsonScanUTF16.cr {
                    return nil
                }
                if c != JsonScanUTF16.space, c != JsonScanUTF16.tab {
                    return (i, c)
                }
                i += 1
            }
            return nil
        }

        /// Returns `true` when `open`/`close` form a valid JSON bracket pair (`{}`or `[]`).
        private func isMatchingOpenClosePair(open: UInt16, close: UInt16) -> Bool {
            (open == JsonScanUTF16.braceOpen && close == JsonScanUTF16.braceClose) ||
                (open == JsonScanUTF16.bracketOpen && close == JsonScanUTF16.bracketClose)
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
            let continueAutocomplete = suggestion.kind == .message
                || suggestion.kind == .repeated
                || suggestion.kind == .enumField
                || suggestion.kind == .wktString
                || suggestion.kind == .bool

            if continueAutocomplete, let protoFile = parent.protoFile {
                let newText = textView.string
                let offset = textView.selectedRange().location
                pendingHintTask?.cancel()
                pendingUpdateTask?.cancel()
                pendingUpdateTask = Task { @MainActor [weak textView] in
                    await vm.textDidChange(newText, cursorOffset: offset, protoFile: protoFile)
                    guard !Task.isCancelled else { return }
                    guard let textView else { return }

                    self.showValueTypeHint(vm.valueTypeHint, in: textView)
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
                scheduleValueTypeHintRefresh(in: textView, vm: vm)
            }
        }

        /// Loads the type name for the caret and draws it. Does not open or close the suggestion list.
        private func scheduleValueTypeHintRefresh(in textView: NSTextView, vm: AutocompleteViewModel) {
            guard let protoFile = parent.protoFile else {
                showValueTypeHint(nil, in: textView)
                return
            }

            let text = textView.string
            let offset = textView.selectedRange().location
            pendingHintTask?.cancel()
            pendingHintTask = Task { @MainActor [weak textView] in
                await vm.refreshValueTypeHint(text, cursorOffset: offset, protoFile: protoFile)
                guard !Task.isCancelled else { return }
                guard let textView else { return }

                self.showValueTypeHint(vm.valueTypeHint, in: textView)
            }
        }

        /// Draws `hint` at the caret. The label is not text, so it never enters the document or undo.
        /// It stays on the caret's line and is hidden when it would cover the next field.
        private func showValueTypeHint(_ hint: JsonValueTypeHint?, in textView: NSTextView) {
            let selection = textView.selectedRange()
            guard let hint, selection.length == 0, textView.window != nil else {
                hideValueTypeHint()
                return
            }

            let origin = hintOrigin(in: textView, cursorUTF16: selection.location)
            guard origin.height > 0 else {
                hideValueTypeHint()
                return
            }

            if valueTypeHintLabel.superview !== textView {
                valueTypeHintLabel.removeFromSuperview()
                textView.addSubview(valueTypeHintLabel)
            }
            valueTypeHintLabel.stringValue = hint.name
            valueTypeHintLabel.font = JsonEditorMetrics.font
            valueTypeHintLabel.textColor = JsonHighlightTheme.placeholderColor(for: hint.kind)
            valueTypeHintLabel.sizeToFit()
            let size = valueTypeHintLabel.frame.size
            let room = placeholderRoom(
                in: textView,
                caret: origin,
                cursorUTF16: selection.location)
            guard room >= size.width else {
                hideValueTypeHint()
                return
            }

            var frame = NSRect(
                x: origin.minX,
                y: origin.midY - size.height / 2,
                width: size.width,
                height: size.height)
            if frame.height > origin.height {
                frame.size.height = origin.height
            }
            if frame.minY < origin.minY {
                frame.origin.y = origin.minY
            }
            if frame.maxY > origin.maxY {
                frame.origin.y = origin.maxY - frame.height
            }
            valueTypeHintLabel.frame = frame
            valueTypeHintLabel.setAccessibilityElement(true)
            valueTypeHintLabel.setAccessibilityRole(.staticText)
            valueTypeHintLabel.setAccessibilityLabel("\(hint.name), value type")
            valueTypeHintLabel.isHidden = false
        }

        private func hideValueTypeHint() {
            valueTypeHintLabel.isHidden = true
            valueTypeHintLabel.setAccessibilityElement(false)
        }

        /// Shows `text`, expanding valid inline JSON. Writes the pretty form back when it differs.
        func syncDisplayedText(_ text: String, to textView: NSTextView) {
            let display = expandedInline(text)
            guard textView.string != display else {
                writeBack(display, whenDifferentFrom: text)
                return
            }

            let previous = textView.string
            let selection = textView.selectedRange()
            suppressTextDidChange = true
            defer { suppressTextDidChange = false }
            textView.string = display
            let length = (display as NSString).length
            let location = previous == text
                ? JsonInlineDocument.cursor(in: display, matching: text, cursorUTF16: selection.location)
                : selection.location
            let clamped = min(max(0, location), length)
            let rangeLength = min(selection.length, max(0, length - clamped))
            textView.setSelectedRange(NSRange(location: clamped, length: rangeLength))
            writeBack(display, whenDifferentFrom: text)
            refreshValueTypeHintAfterDisplayChange(in: textView)
        }

        /// Format and fill-defaults replace the document from outside a keystroke.
        /// The placeholder is computed again for the caret in that text.
        private func refreshValueTypeHintAfterDisplayChange(in textView: NSTextView) {
            guard let vm = parent.autocompleteViewModel else {
                showValueTypeHint(nil, in: textView)
                return
            }

            scheduleValueTypeHintRefresh(in: textView, vm: vm)
        }

        /// Expands a valid one-line document into pretty JSON without moving the caret out of its value.
        private func applyInlineFormat(to textView: NSTextView) {
            let original = textView.string
            let formatted = expandedInline(original)
            guard formatted != original else { return }

            let cursor = textView.selectedRange().location
            let newCursor = JsonInlineDocument.cursor(in: formatted, matching: original, cursorUTF16: cursor)
            writeDocument(formatted, caret: newCursor, in: textView)
        }

        /// Replaces the whole document without recording a second undo action for the replacement itself.
        private func writeDocument(_ text: String, caret: Int, in textView: NSTextView) {
            let wasSuppressed = suppressTextDidChange
            suppressTextDidChange = true
            textView.undoManager?.disableUndoRegistration()
            if let storage = textView.textStorage {
                storage.beginEditing()
                storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
                storage.endEditing()
            } else {
                textView.string = text
            }
            let length = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(max(0, caret), length), length: 0))
            parent.text = text
            textView.undoManager?.enableUndoRegistration()
            suppressTextDidChange = wasSuppressed
            isApplyingStyle = true
            JsonTextStyler.apply(to: textView)
            isApplyingStyle = false
        }

        private func expandedInline(_ text: String) -> String {
            parent.formatInlineJSON?(text) ?? text
        }

        private func writeBack(_ display: String, whenDifferentFrom text: String) {
            guard display != text, parent.text != display else { return }

            parent.text = display
        }

        /// The label's top-left slot: after the closing quote or comma, or at the caret when the value has not started.
        private func hintOrigin(in textView: NSTextView, cursorUTF16: Int) -> NSRect {
            switch JsonValueTypeHintPlacement.anchor(in: textView.string, cursorUTF16: cursorUTF16) {
            case .caret:
                return caretRect(in: textView, characterIndex: cursorUTF16) ?? .zero

            case let .afterCharacter(index):
                guard let glyph = glyphRect(in: textView, characterIndex: index),
                      let line = lineFragment(in: textView, characterIndex: index)
                else { return .zero }

                let gap = (" " as NSString).size(withAttributes: [.font: JsonEditorMetrics.font]).width
                return NSRect(x: glyph.maxX + gap, y: line.minY, width: 1, height: line.height)
            }
        }

        /// Horizontal room from the caret to the next field on the same visual line, and no farther
        /// than the text container. A field on the following line does not steal that room.
        private func placeholderRoom(
            in textView: NSTextView,
            caret: NSRect,
            cursorUTF16: Int)
            -> CGFloat
        {
            let rawWidth = textView.textContainer?.containerSize.width ?? textView.bounds.width
            let containerWidth = rawWidth > 100_000 ? textView.bounds.width : rawWidth
            let containerRight = textView.textContainerOrigin.x + containerWidth
            let lineRoom = containerRight - caret.minX - 4
            guard let blocking = JsonValueTypeHintPlacement.blockingCharacterUTF16(
                in: textView.string,
                cursorUTF16: cursorUTF16),
                let blockRect = glyphRect(in: textView, characterIndex: blocking),
                let blockLine = lineFragment(in: textView, characterIndex: blocking),
                abs(blockLine.minY - caret.minY) < 0.5
            else { return lineRoom }

            return min(lineRoom, blockRect.minX - caret.minX - 2)
        }

        /// Caret rectangle in text-view coordinates.
        /// At a soft wrap the glyph index points at the next visual line; the placeholder stays
        /// at the end of the previous line so it does not land on the following field.
        private func caretRect(in textView: NSTextView, characterIndex: Int) -> NSRect? {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return nil }

            let ns = textView.string as NSString
            let index = min(max(0, characterIndex), ns.length)
            layoutManager.ensureLayout(for: textContainer)
            let origin = textView.textContainerOrigin

            if index == ns.length {
                if ns.length == 0 || isLineBreak(ns.character(at: ns.length - 1)) {
                    var extra = layoutManager.extraLineFragmentRect
                    if extra.height == 0, ns.length > 0 {
                        let glyph = layoutManager.glyphIndexForCharacter(at: ns.length - 1)
                        extra = layoutManager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
                        extra.origin.x = extra.maxX
                    }
                    extra.size.width = 1
                    extra.origin.x += origin.x
                    extra.origin.y += origin.y
                    return extra
                }
                let glyph = layoutManager.glyphIndexForCharacter(at: ns.length - 1)
                let glyphRect = layoutManager.boundingRect(
                    forGlyphRange: NSRange(location: glyph, length: 1),
                    in: textContainer)
                let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                return NSRect(
                    x: glyphRect.maxX + origin.x,
                    y: line.minY + origin.y,
                    width: 1,
                    height: line.height)
            }

            let glyph = layoutManager.glyphIndexForCharacter(at: index)
            if index > 0, !isLineBreak(ns.character(at: index - 1)) {
                var lineRange = NSRange()
                _ = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &lineRange)
                if glyph == lineRange.location, lineRange.location > 0 {
                    let previousGlyph = lineRange.location - 1
                    let used = layoutManager.lineFragmentUsedRect(forGlyphAt: previousGlyph, effectiveRange: nil)
                    return NSRect(
                        x: used.maxX + origin.x,
                        y: used.minY + origin.y,
                        width: 1,
                        height: used.height)
                }
            }

            let glyphRect = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyph, length: 1),
                in: textContainer)
            let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            return NSRect(
                x: glyphRect.minX + origin.x,
                y: line.minY + origin.y,
                width: 1,
                height: max(line.height, 1))
        }

        private func glyphRect(in textView: NSTextView, characterIndex: Int) -> NSRect? {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return nil }

            let length = (textView.string as NSString).length
            guard characterIndex >= 0, characterIndex < length else { return nil }

            layoutManager.ensureLayout(for: textContainer)
            let glyph = layoutManager.glyphIndexForCharacter(at: characterIndex)
            var rect = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyph, length: 1),
                in: textContainer)
            rect.origin.x += textView.textContainerOrigin.x
            rect.origin.y += textView.textContainerOrigin.y
            return rect
        }

        private func lineFragment(in textView: NSTextView, characterIndex: Int) -> NSRect? {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return nil }

            let length = (textView.string as NSString).length
            guard characterIndex >= 0, characterIndex < length else { return nil }

            layoutManager.ensureLayout(for: textContainer)
            let glyph = layoutManager.glyphIndexForCharacter(at: characterIndex)
            var rect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            rect.origin.x += textView.textContainerOrigin.x
            rect.origin.y += textView.textContainerOrigin.y
            return rect
        }

        private func isLineBreak(_ character: UInt16) -> Bool {
            character == JsonScanUTF16.lf || character == JsonScanUTF16.cr
        }

        // MARK: - Popover positioning

        private func showPopoverIfNeeded(in textView: NSTextView) {
            guard textView.window != nil else { return }

            showAutocompletePopover(in: textView)
            textView.window?.makeFirstResponder(textView)
        }

        /// Opens the suggestion panel on the caret, or closes it when the caret is outside the viewport.
        func showAutocompletePopover(in textView: NSTextView) {
            let contentSize = idealAutocompletePopoverContentSize()
            guard let placement = autocompletePopoverPlacement(in: textView, contentSize: contentSize),
                  let caret = caretAnchorRect(in: textView)
            else {
                autocompletePopover.close()
                return
            }

            autocompletePopover.contentSize = NSSize(width: placement.frame.width, height: placement.frame.height)
            if autocompletePopover.isShown {
                autocompletePopover.close()
            }
            let edge: NSRectEdge = placement.side == .below ? .maxY : .minY
            autocompletePopover.show(relativeTo: caret, of: textView, preferredEdge: edge)
        }

        /// The panel frame in the text view's top-left, y-down space. Nil when the caret is scrolled away.
        func autocompletePopoverPlacement(in textView: NSTextView) -> AutocompletePopoverPlacement? {
            autocompletePopoverPlacement(in: textView, contentSize: idealAutocompletePopoverContentSize())
        }

        private func autocompletePopoverPlacement(
            in textView: NSTextView,
            contentSize: CGSize)
            -> AutocompletePopoverPlacement?
        {
            guard let caret = caretAnchorRect(in: textView) else { return nil }

            return PlaceAutocompletePopover.place(
                caret: caret.editorRect,
                visibleEditor: textView.visibleRect.editorRect,
                limits: popoverLimits(around: caret, in: textView).editorRect,
                contentSize: EditorSize(width: Double(contentSize.width), height: Double(contentSize.height)))
        }

        /// Unclamped panel size for the current suggestions. The placement then shrinks it to the free room.
        private func idealAutocompletePopoverContentSize() -> CGSize {
            guard let host = autocompletePopover.contentViewController as? NSHostingController<AutocompletePopoverView>
            else {
                return CGSize(width: AutocompletePopoverSize.minWidth, height: PlaceAutocompletePopover.minimumHeight)
            }

            let previous = host.view.frame
            host.view.frame = NSRect(x: 0, y: 0, width: AutocompletePopoverSize.maxWidth, height: 4000)
            host.rootView = host.rootView
            host.view.layoutSubtreeIfNeeded()
            let proposed = host.sizeThatFits(in: CGSize(width: AutocompletePopoverSize.maxWidth, height: 10000))
            host.view.frame = previous
            return AutocompletePopoverSize.fitted(CGSize(
                width: max(proposed.width, 1),
                height: max(proposed.height, 1)))
        }

        /// The line fragment at the caret, one point wide, in text view coordinates.
        private func caretAnchorRect(in textView: NSTextView) -> NSRect? {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer
            else { return nil }

            layoutManager.ensureLayout(for: textContainer)
            let origin = textView.textContainerOrigin
            let length = (textView.string as NSString).length
            let location = min(max(0, textView.selectedRange().location), length)

            if length == 0 {
                let font = textView.font ?? JsonEditorMetrics.font
                let lineHeight = layoutManager.defaultLineHeight(for: font)
                return NSRect(x: origin.x, y: origin.y, width: 1, height: max(lineHeight, 1))
            }

            if location == length,
               textView.string.hasSuffix("\n"),
               layoutManager.extraLineFragmentRect.height > 0
            {
                var extra = layoutManager.extraLineFragmentRect
                extra.origin.x += origin.x
                extra.origin.y += origin.y
                extra.size.width = 1
                return extra
            }

            let index = min(location, length - 1)
            let glyph = layoutManager.glyphIndexForCharacter(at: index)
            var line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let glyphBounds = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyph, length: 1),
                in: textContainer)
            line.origin.x = (location >= length ? glyphBounds.maxX : glyphBounds.minX) + origin.x
            line.origin.y += origin.y
            line.size.width = 1
            return line
        }

        /// The window area the panel may occupy, cropped to the visible screen when the caret stays inside it.
        private func popoverLimits(around caret: NSRect, in textView: NSTextView) -> NSRect {
            guard let window = textView.window, let content = window.contentView else {
                return textView.visibleRect
            }

            var limits = textView.convert(content.visibleRect, from: content)
            if let screen = window.screen?.visibleFrame {
                let onScreen = textView.convert(window.convertFromScreen(screen), from: nil)
                let cropped = limits.intersection(onScreen)
                if cropped.width > 1, cropped.height > 1, cropped.intersects(caret) {
                    limits = cropped
                }
            }
            if limits.width < 1 || limits.height < 1 {
                return textView.visibleRect
            }
            return limits
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
            isApplyingSmartInsert = true
            defer { isApplyingSmartInsert = false }
            // Preserve the original cursor offset before any range adjustments so that
            // value-specific range logic always operates on the actual cursor position.
            let originalCursorOffset = textView.selectedRange().location
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
            // For value-type suggestions (enum values, WKT defaults) the cursor may sit
            // inside an existing quoted value placeholder — e.g. `"field": "█"` or
            // `"field": "partial█"`. `findPartialStringStart` may only capture the opening
            // `"` without the closing one, leaving a dangling `"` after insertion. We
            // override the range with a scan that covers the full `"..."` token instead.
            let isValueSuggestion = suggestion.kind == .enum
                || suggestion.kind == .wktDefault
                || suggestion.kind == .boolLiteral
            if isValueSuggestion {
                range = smartInsert.valueStringRange(in: ns, cursorOffset: originalCursorOffset) ?? range
            }
            // Compute line indentation from pre-insertion text so the snippet and all
            // closing-brace patches share a consistent base indent.
            let lineIndent = smartInsert.lineIndentation(in: ns, at: range.location)
            let (insertText, cursorBack) = smartInsert.smartInsertComponents(
                for: suggestion, lineIndent: lineIndent)
            guard !insertText.isEmpty else { return }

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

                var emittedMiddleCount = 0

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
                        emittedMiddleCount = innerBraces
                    }
                } else {
                    let missingMiddle = smartInsert.unclosedBraceCount(in: textView.string)
                    let skipMiddleInsertion = nextSig.map { pair in
                        pair.scalar == JsonScanUTF16.comma || pair.scalar == JsonScanUTF16.colon
                    } ?? false
                    if !skipMiddleInsertion, missingMiddle > 1 {
                        emittedMiddleCount = missingMiddle - 1
                        // Each parent-scope `}` goes one level above the cursor, so base is lineIndent - 2.
                        let middleBase = lineIndent.count >= 2 ? String(lineIndent.dropLast(2)) : ""
                        let patch = smartInsert.indentedClosingSuffix(count: emittedMiddleCount, baseIndent: middleBase)
                        Self.replaceInTextViewWithoutShouldChangeGate(
                            textView,
                            range: NSRange(location: insertEnd, length: 0),
                            string: patch)
                    }
                }

                let cursorPos = insertEnd - cursorBack

                let missingTrailing = smartInsert.unclosedBraceCount(in: textView.string)
                if missingTrailing == 1 {
                    // The trailing `}` closes the scope that *contains* the cursor, so it must
                    // be one indentation level out from `lineIndent` (the cursor's own level).
                    var trailingIndent = lineIndent.count >= 2 ? String(lineIndent.dropLast(2)) : ""
                    for _ in 0 ..< emittedMiddleCount {
                        trailingIndent = trailingIndent.count >= 2
                            ? String(trailingIndent.dropLast(2))
                            : ""
                    }
                    let suffix = smartInsert.indentedClosingSuffix(count: 1, baseIndent: trailingIndent)
                    let endRange = NSRange(location: textView.string.utf16.count, length: 0)
                    Self.replaceInTextViewWithoutShouldChangeGate(textView, range: endRange, string: suffix)
                }

                parent.text = textView.string
                textView.setSelectedRange(NSRange(location: max(0, cursorPos), length: 0))
                applyInlineFormat(to: textView)
            }
        }
    }
}

private extension NSRect {
    var editorRect: EditorRect {
        EditorRect(x: Double(origin.x), y: Double(origin.y), width: Double(size.width), height: Double(size.height))
    }
}

/// Placeholder drawn over the caret. `hitTest` returns nil so it never takes clicks or focus.
private final class ValueTypeHintLabel: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBezeled = false
        isBordered = false
        isEditable = false
        isSelectable = false
        drawsBackground = false
        backgroundColor = .clear
        font = JsonEditorMetrics.font
        alignment = .left
        maximumNumberOfLines = 1
        lineBreakMode = .byClipping
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}

#if DEBUG
    #Preview("Empty", traits: .fixedLayout(width: 390, height: 280)) {
        JSONTextEditor(text: .constant(""), smartInsert: SmartInsertService())
    }

    #Preview("Document", traits: .fixedLayout(width: 390, height: 280)) {
        JSONTextEditor(text: .constant(PreviewJSON.shortObject), smartInsert: SmartInsertService())
    }

    #Preview("Long Content", traits: .fixedLayout(width: 390, height: 280)) {
        JSONTextEditor(text: .constant(PreviewJSON.longDocument), smartInsert: SmartInsertService())
    }
#endif
