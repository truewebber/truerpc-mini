import Foundation

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

    /// `true` when the caret sits where a value can start and no value character has been typed.
    static func isEmptySlot(in text: String, cursorUTF16: Int) -> Bool {
        let ns = text as NSString
        let cursor = min(max(0, cursorUTF16), ns.length)
        var index = cursor - 1
        while index >= 0 {
            let character = ns.character(at: index)
            if isWhitespace(character) {
                index -= 1
                continue
            }
            if character == JsonScanUTF16.colon
                || character == JsonScanUTF16.bracketOpen
                || character == JsonScanUTF16.comma
            {
                return true
            }
            if character == JsonScanUTF16.quote {
                return nextNonWhitespace(in: ns, from: cursor) == JsonScanUTF16.quote
            }
            return false
        }
        return false
    }

    private static func nextNonWhitespace(in text: NSString, from index: Int) -> UInt16? {
        var cursor = index
        while cursor < text.length {
            let character = text.character(at: cursor)
            if !isWhitespace(character) {
                return character
            }
            cursor += 1
        }
        return nil
    }

    private static func isWhitespace(_ character: UInt16) -> Bool {
        character == JsonScanUTF16.space
            || character == JsonScanUTF16.tab
            || character == JsonScanUTF16.lf
            || character == JsonScanUTF16.cr
    }
}
