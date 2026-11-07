import Foundation

/// Snippet text and JSON scans used when a suggestion is inserted into the editor.
public protocol SmartInsertServiceProtocol: Sendable {
    func smartInsertComponents(
        for suggestion: AutocompleteSuggestion,
        lineIndent: String)
        -> (text: String, cursorBack: Int)

    func unclosedBraceCount(in text: String) -> Int

    func arrayBracketBalanceInPrefix(ns: NSString, endUTF16: Int) -> Int

    func netBraceCountInUTF16Range(ns: NSString, fromUTF16: Int, toUTF16: Int) -> Int

    func nextSignificantUTF16IndexAndScalar(
        ns: NSString,
        fromUTF16: Int)
        -> (index: Int, scalar: UInt16)?

    func indexOfClosingBracketForContainingArray(ns: NSString, fromUTF16: Int) -> Int?

    func indexOfMatchingOpenBracket(ns: NSString, closingBracketUTF16: Int) -> Int?

    func findBareTextStart(in ns: NSString, cursorOffset: Int) -> Int?

    func findPartialStringStart(in ns: NSString, cursorOffset: Int) -> Int?

    func valueStringRange(in ns: NSString, cursorOffset: Int) -> NSRange?

    func isInsideStringLiteral(in ns: NSString, at utf16Offset: Int) -> Bool

    func lineIndentation(in ns: NSString, at utf16Offset: Int) -> String

    func indentedClosingSuffix(count: Int, baseIndent: String) -> String
}
