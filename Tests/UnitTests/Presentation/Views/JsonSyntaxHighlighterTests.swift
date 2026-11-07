import AppKit
import SwiftUI
import XCTest
@testable import TrueRPCMini

final class JsonSyntaxHighlighterTests: XCTestCase {
    private let highlighter = JsonSyntaxHighlighter()

    func test_spans_whenTextIsEmpty_returnsNoSpans() {
        XCTAssertEqual(highlighter.spans(in: ""), [])
        XCTAssertEqual(highlighter.spans(in: " \n\t"), [])
    }

    func test_spans_whenObject_marksKeysStringsNumbersLiteralsAndPunctuation() {
        let text = """
        {
          "userId": 1,
          "name": "Alice",
          "active": true,
          "note": null
        }
        """

        let spans = highlighter.spans(in: text)

        XCTAssertEqual(
            spans.map(\.kind),
            [
                .punctuation, .key, .punctuation, .number, .punctuation,
                .key, .punctuation, .string, .punctuation,
                .key, .punctuation, .literal, .punctuation,
                .key, .punctuation, .literal, .punctuation,
            ])
        XCTAssertEqual(
            fragments(text, spans),
            [
                "{", "\"userId\"", ":", "1", ",",
                "\"name\"", ":", "\"Alice\"", ",",
                "\"active\"", ":", "true", ",",
                "\"note\"", ":", "null", "}",
            ])
    }

    func test_spans_whenArrayOfStrings_keepsThemAsValues() {
        let text = "[\"Alice\", \"Bob\"]"

        let spans = highlighter.spans(in: text)

        XCTAssertEqual(spans.map(\.kind), [.punctuation, .string, .punctuation, .string, .punctuation])
        XCTAssertEqual(fragments(text, spans), ["[", "\"Alice\"", ",", "\"Bob\"", "]"])
    }

    func test_spans_whenQuoteIsEscaped_keepsItInsideTheString() {
        let text = "{\"a\":\"b\\\"c\"}"

        let spans = highlighter.spans(in: text)

        XCTAssertEqual(spans.map(\.kind), [.punctuation, .key, .punctuation, .string, .punctuation])
        XCTAssertEqual(fragments(text, spans), ["{", "\"a\"", ":", "\"b\\\"c\"", "}"])
    }

    func test_spans_whenValueStringIsUnclosed_colorsItThroughTheEnd() {
        let text = "{\"a\":\"Alice"

        let spans = highlighter.spans(in: text)

        XCTAssertEqual(spans.map(\.kind), [.punctuation, .key, .punctuation, .string])
        XCTAssertEqual(fragments(text, spans), ["{", "\"a\"", ":", "\"Alice"])
    }

    func test_spans_whenKeyIsUnclosed_colorsItAsAKeyThroughTheEnd() {
        let text = "{\"user"

        XCTAssertEqual(highlighter.spans(in: text).map(\.kind), [.punctuation, .key])
        XCTAssertEqual(fragments(text, highlighter.spans(in: text)), ["{", "\"user"])
    }

    func test_spans_whenTailIsNotJson_leavesThoseCharactersUncolored() {
        let text = "{\"a\":1 oops}"

        let spans = highlighter.spans(in: text)

        XCTAssertEqual(fragments(text, spans), ["{", "\"a\"", ":", "1", "}"])
    }

    func test_spans_whenNumberHasSignFractionAndExponent_takesTheWholeNumber() {
        let text = "[-1.5e+2]"

        XCTAssertEqual(fragments(text, highlighter.spans(in: text)), ["[", "-1.5e+2", "]"])
        XCTAssertEqual(highlighter.spans(in: text).map(\.kind), [.punctuation, .number, .punctuation])
    }

    func test_spans_whenMinusIsAlone_leavesItUncolored() {
        let text = "[-]"

        XCTAssertEqual(fragments(text, highlighter.spans(in: text)), ["[", "]"])
    }

    func test_spans_whenNested_marksTheInnerNameAsAKey() {
        let text = "{\"user\":{\"id\":1}}"

        let keys = highlighter.spans(in: text).filter { $0.kind == .key }

        XCTAssertEqual(fragments(text, keys), ["\"user\"", "\"id\""])
    }

    func test_spans_whenStringContainsAnEmoji_usesUTF16Offsets() {
        let text = "\"🙂\""

        let spans = highlighter.spans(in: text)

        XCTAssertEqual(spans.map(\.kind), [.string])
        XCTAssertEqual(spans.first?.startUTF16, 0)
        XCTAssertEqual(spans.first?.endUTF16, text.utf16.count)
    }

    func test_theme_usesDistinctAdaptiveColors() {
        XCTAssertEqual(JsonHighlightTheme.swiftUIColor(for: .key), .blue)
        XCTAssertEqual(JsonHighlightTheme.swiftUIColor(for: .string), .brown)
        XCTAssertEqual(JsonHighlightTheme.swiftUIColor(for: .number), .teal)
        XCTAssertEqual(JsonHighlightTheme.swiftUIColor(for: .literal), .purple)
        XCTAssertEqual(JsonHighlightTheme.swiftUIColor(for: .punctuation), .secondary)
        XCTAssertTrue(JsonHighlightTheme.appKitColor(for: .key).isEqual(NSColor.systemBlue))
        XCTAssertTrue(JsonHighlightTheme.appKitColor(for: .string).isEqual(NSColor.systemBrown))
        XCTAssertTrue(JsonHighlightTheme.appKitColor(for: .number).isEqual(NSColor.systemTeal))
        XCTAssertTrue(JsonHighlightTheme.appKitColor(for: .literal).isEqual(NSColor.systemPurple))
        XCTAssertTrue(JsonHighlightTheme.appKitColor(for: .punctuation).isEqual(NSColor.secondaryLabelColor))
    }

    func test_metrics_useMonospacedTextWithOpenLineSpacing() {
        XCTAssertEqual(JsonEditorMetrics.fontSize, 13)
        XCTAssertEqual(JsonEditorMetrics.lineSpacing, 4)
        XCTAssertEqual(JsonEditorMetrics.font.pointSize, 13)
        XCTAssertTrue(JsonEditorMetrics.font.isFixedPitch)
        XCTAssertEqual(JsonEditorMetrics.paragraphStyle.lineSpacing, 4)
    }

    func test_attributedText_colorsTheKeyAndLeavesTheStringSelectable() {
        let text = "{\"a\":1}"
        let attributed = highlighter.attributedText(text)
        let keyIndex = AttributedString.Index(String.Index(utf16Offset: 2, in: text), within: attributed)
        let numberIndex = AttributedString.Index(String.Index(utf16Offset: 5, in: text), within: attributed)

        XCTAssertEqual(String(attributed.characters), text)
        XCTAssertEqual(keyIndex.map { attributed[$0 ... $0].foregroundColor }, .blue)
        XCTAssertEqual(numberIndex.map { attributed[$0 ... $0].foregroundColor }, .teal)
    }

    @MainActor
    func test_applyStyle_keepsTheStringAndSelectionAndPaintsTheKey() {
        let text = "{\"a\":1}"
        let textView = NSTextView()
        textView.string = text
        textView.setSelectedRange(NSRange(location: 2, length: 0))

        JsonTextStyler.apply(to: textView)

        XCTAssertEqual(textView.string, text)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 2, length: 0))
        let font = textView.textStorage?.attribute(.font, at: 2, effectiveRange: nil) as? NSFont
        XCTAssertEqual(font?.pointSize, 13)
        XCTAssertEqual(font?.isFixedPitch, true)
        let style = textView.textStorage?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        XCTAssertEqual(style?.lineSpacing, 4)
        let color = textView.layoutManager?.temporaryAttribute(
            .foregroundColor,
            atCharacterIndex: 2,
            effectiveRange: nil) as? NSColor
        XCTAssertTrue(color?.isEqual(JsonHighlightTheme.appKitColor(for: .key)) == true)
    }

    private func fragments(_ text: String, _ spans: [JsonSyntaxSpan]) -> [String] {
        spans.map { span in
            let start = String.Index(utf16Offset: span.startUTF16, in: text)
            let end = String.Index(utf16Offset: span.endUTF16, in: text)
            return String(text[start ..< end])
        }
    }
}
