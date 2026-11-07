import Foundation

/// Where a value-type placeholder is drawn relative to the caret.
enum JsonValueHintAnchor: Equatable {
    /// The caret is in open whitespace, such as after `:`.
    case caret
    /// Draw after this character (the closing quote, bracket, or the comma that follows it).
    case afterCharacter(Int)
}

/// Decides when the editor may draw a type name at the caret.
/// The name is a placeholder: it is shown only while the value slot is still empty.
enum JsonValueTypeHintPlacement {
    static func shouldShow(
        context: AutocompleteContext,
        text: String,
        cursorUTF16: Int)
        -> Bool
    {
        guard context.mode == .enumValue || context.mode == .arrayElement else { return false }
        guard context.partialKey.isEmpty else { return false }

        return isEmptySlot(in: text, cursorUTF16: cursorUTF16)
    }

    /// `true` when the caret sits where a value can start and no value has been written.
    /// A filled string, number, bool, null, object, or array is not an empty slot, even when the
    /// caret is still in the whitespace before the next field.
    static func isEmptySlot(in text: String, cursorUTF16: Int) -> Bool {
        let ns = text as NSString
        let cursor = min(max(0, cursorUTF16), ns.length)
        if isInsideEmptyQuotes(in: ns, cursor: cursor) {
            return true
        }
        guard let delimiter = previousNonWhitespace(in: ns, before: cursor),
              isValueDelimiter(delimiter)
        else { return false }
        guard let next = nextNonWhitespace(in: ns, from: cursor) else { return true }

        return isValueCloser(next)
    }

    /// Where the type name is drawn. Inside `""` or `[]` it sits after the closing mark and the comma,
    /// so the punctuation stays readable. A bare caret after `:` stays where it is.
    static func anchor(in text: String, cursorUTF16: Int) -> JsonValueHintAnchor {
        let ns = text as NSString
        let cursor = min(max(0, cursorUTF16), ns.length)
        if let closingQuote = emptyQuoteCloseIndex(in: ns, cursor: cursor) {
            return .afterCharacter(trailingComma(in: ns, after: closingQuote) ?? closingQuote)
        }
        if let closingBracket = emptyBracketCloseIndex(in: ns, cursor: cursor) {
            return .afterCharacter(trailingComma(in: ns, after: closingBracket) ?? closingBracket)
        }
        return .caret
    }

    /// First character the placeholder must not draw over, so a one-line value does not cover the next field.
    /// Closing quotes, whitespace, a single comma, and `}` / `]` are part of the empty slot.
    static func blockingCharacterUTF16(in text: String, cursorUTF16: Int) -> Int? {
        let ns = text as NSString
        let cursor = min(max(0, cursorUTF16), ns.length)
        var index = cursor
        if isInsideEmptyQuotes(in: ns, cursor: cursor) {
            while index < ns.length, ns.character(at: index) != JsonScanUTF16.quote {
                index += 1
            }
            if index < ns.length {
                index += 1
            }
        } else if let closingBracket = emptyBracketCloseIndex(in: ns, cursor: cursor) {
            index = closingBracket + 1
        }
        index = skipWhitespace(in: ns, from: index)
        if index < ns.length, ns.character(at: index) == JsonScanUTF16.comma {
            index = skipWhitespace(in: ns, from: index + 1)
        }
        guard index < ns.length else { return nil }

        let character = ns.character(at: index)
        if isValueCloser(character) {
            return nil
        }
        return index
    }

    /// The caret is between a value's opening quote and its closing quote, with nothing typed between them.
    /// A space counts as text: the placeholder hides as soon as the value is no longer empty.
    private static func isInsideEmptyQuotes(in text: NSString, cursor: Int) -> Bool {
        guard cursor > 0, cursor < text.length else { return false }
        guard text.character(at: cursor - 1) == JsonScanUTF16.quote else { return false }
        guard text.character(at: cursor) == JsonScanUTF16.quote else { return false }

        return isValueOpeningQuote(in: text, quoteIndex: cursor - 1)
    }

    private static func emptyQuoteCloseIndex(in text: NSString, cursor: Int) -> Int? {
        guard isInsideEmptyQuotes(in: text, cursor: cursor) else { return nil }

        var index = cursor
        while index < text.length {
            if text.character(at: index) == JsonScanUTF16.quote {
                return index
            }
            index += 1
        }
        return nil
    }

    private static func emptyBracketCloseIndex(in text: NSString, cursor: Int) -> Int? {
        guard cursor > 0 else { return nil }

        var open = cursor - 1
        while open >= 0 {
            let character = text.character(at: open)
            if character == JsonScanUTF16.bracketOpen {
                break
            }
            if !isWhitespace(character) {
                return nil
            }
            open -= 1
        }
        guard open >= 0, text.character(at: open) == JsonScanUTF16.bracketOpen else { return nil }

        var close = cursor
        while close < text.length {
            let character = text.character(at: close)
            if character == JsonScanUTF16.bracketClose {
                return close
            }
            if !isWhitespace(character) {
                return nil
            }
            close += 1
        }
        return nil
    }

    /// The comma that follows `punctuation` on the same line, if the only characters between them are spaces.
    private static func trailingComma(in text: NSString, after punctuation: Int) -> Int? {
        var index = punctuation + 1
        while index < text.length {
            let character = text.character(at: index)
            if character == JsonScanUTF16.comma {
                return index
            }
            if character != JsonScanUTF16.space, character != JsonScanUTF16.tab {
                return nil
            }
            index += 1
        }
        return nil
    }

    /// The quote starts a value when the previous token is `:`, `[`, or `,`.
    /// A closing quote of a filled string fails this check, so the gap before the next key is not empty.
    private static func isValueOpeningQuote(in text: NSString, quoteIndex: Int) -> Bool {
        var index = quoteIndex - 1
        while index >= 0 {
            let character = text.character(at: index)
            if isWhitespace(character) {
                index -= 1
                continue
            }
            return isValueDelimiter(character)
        }
        return false
    }

    private static func previousNonWhitespace(in text: NSString, before cursor: Int) -> UInt16? {
        var index = cursor - 1
        while index >= 0 {
            let character = text.character(at: index)
            if !isWhitespace(character) {
                return character
            }
            index -= 1
        }
        return nil
    }

    private static func nextNonWhitespace(in text: NSString, from index: Int) -> UInt16? {
        let cursor = skipWhitespace(in: text, from: index)
        guard cursor < text.length else { return nil }

        return text.character(at: cursor)
    }

    private static func skipWhitespace(in text: NSString, from index: Int) -> Int {
        var cursor = index
        while cursor < text.length, isWhitespace(text.character(at: cursor)) {
            cursor += 1
        }
        return cursor
    }

    private static func isValueDelimiter(_ character: UInt16) -> Bool {
        character == JsonScanUTF16.colon
            || character == JsonScanUTF16.bracketOpen
            || character == JsonScanUTF16.comma
    }

    private static func isValueCloser(_ character: UInt16) -> Bool {
        character == JsonScanUTF16.comma
            || character == JsonScanUTF16.braceClose
            || character == JsonScanUTF16.bracketClose
    }

    private static func isWhitespace(_ character: UInt16) -> Bool {
        character == JsonScanUTF16.space
            || character == JsonScanUTF16.tab
            || character == JsonScanUTF16.lf
            || character == JsonScanUTF16.cr
    }
}
