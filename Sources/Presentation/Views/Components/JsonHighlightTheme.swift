import AppKit
import SwiftUI

/// System colors for JSON tokens. Status hues stay free for request state, method kind, and TLS.
enum JsonHighlightTheme {
    static func swiftUIColor(for kind: JsonSyntaxKind) -> Color {
        switch kind {
        case .key: .blue
        case .string: .brown
        case .number: .teal
        case .literal: .purple
        case .punctuation: .secondary
        }
    }

    static func appKitColor(for kind: JsonSyntaxKind) -> NSColor {
        switch kind {
        case .key: .systemBlue
        case .string: .systemBrown
        case .number: .systemTeal
        case .literal: .systemPurple
        case .punctuation: .secondaryLabelColor
        }
    }

    /// Ghost color for a type name drawn at an empty value. Token hues stay tied to the JSON scheme.
    static func placeholderColor(for kind: SuggestionKind) -> NSColor {
        let syntax: JsonSyntaxKind? = switch kind {
        case .number: .number
        case .string: .string
        case .bool: .literal
        default: nil
        }
        return NSColor(name: nil, dynamicProvider: { _ in
            let base = syntax.map { appKitColor(for: $0) } ?? .secondaryLabelColor
            return base.withAlphaComponent(0.55)
        })
    }
}

/// Shared type and spacing for the request editor and the response body.
enum JsonEditorMetrics {
    static let fontSize: CGFloat = 13
    static let lineSpacing: CGFloat = 4
    static let textInset = NSSize(width: 4, height: 4)
    static let lineFragmentPadding: CGFloat = 4

    static var font: NSFont {
        NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    static var swiftUIFont: Font {
        .system(size: fontSize, weight: .regular, design: .monospaced)
    }

    static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        return style
    }

    static var storageAttributes: [NSAttributedString.Key: Any] {
        [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.labelColor,
        ]
    }
}

extension JsonSyntaxHighlighter {
    /// The same token colors as the editor, for the read-only response body.
    func attributedText(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for span in spans(in: text) {
            guard let range = range(of: span, in: text),
                  let start = AttributedString.Index(range.lowerBound, within: attributed),
                  let end = AttributedString.Index(range.upperBound, within: attributed),
                  start < end
            else { continue }

            attributed[start ..< end].foregroundColor = JsonHighlightTheme.swiftUIColor(for: span.kind)
        }
        return attributed
    }

    private func range(of span: JsonSyntaxSpan, in text: String) -> Range<String.Index>? {
        guard span.startUTF16 >= 0,
              span.endUTF16 >= span.startUTF16,
              span.endUTF16 <= text.utf16.count
        else { return nil }

        let start = String.Index(utf16Offset: span.startUTF16, in: text)
        let end = String.Index(utf16Offset: span.endUTF16, in: text)
        return start ..< end
    }
}

/// Paints JSON on an `NSTextView`. Colors stay temporary so they never enter the undo stack
/// or the text-change callback. The font is written into the storage only when it is missing,
/// because doing that on every keystroke swallows the next edit.
enum JsonTextStyler {
    static func apply(to textView: NSTextView) {
        ensureStorageAttributes(in: textView)
        applyColors(to: textView)
    }

    static func applyColors(to textView: NSTextView) {
        textView.typingAttributes = JsonEditorMetrics.storageAttributes
        guard let storage = textView.textStorage, let layoutManager = textView.layoutManager else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        if fullRange.length > 0 {
            layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullRange)
            layoutManager.addTemporaryAttribute(
                .font,
                value: JsonEditorMetrics.font,
                forCharacterRange: fullRange)
        }
        for span in JsonSyntaxHighlighter().spans(in: textView.string) {
            let range = NSRange(location: span.startUTF16, length: span.endUTF16 - span.startUTF16)
            guard range.length > 0, NSMaxRange(range) <= storage.length else { continue }

            layoutManager.addTemporaryAttribute(
                .foregroundColor,
                value: JsonHighlightTheme.appKitColor(for: span.kind),
                forCharacterRange: range)
        }
    }

    private static func ensureStorageAttributes(in textView: NSTextView) {
        textView.typingAttributes = JsonEditorMetrics.storageAttributes
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        guard storageNeedsAttributes(storage) else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        let selection = textView.selectedRange()
        textView.undoManager?.disableUndoRegistration()
        storage.beginEditing()
        storage.addAttributes(JsonEditorMetrics.storageAttributes, range: fullRange)
        storage.endEditing()
        textView.undoManager?.enableUndoRegistration()
        if textView.selectedRange() != selection {
            textView.setSelectedRange(selection)
        }
    }

    private static func storageNeedsAttributes(_ storage: NSTextStorage) -> Bool {
        let font = storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let style = storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let fontMatches = font?.pointSize == JsonEditorMetrics.fontSize && font?.isFixedPitch == true
        return !fontMatches || style?.lineSpacing != JsonEditorMetrics.lineSpacing
    }
}
