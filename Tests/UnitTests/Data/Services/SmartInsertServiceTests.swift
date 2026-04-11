import XCTest
@testable import TrueRPCMini

final class SmartInsertServiceTests: XCTestCase {
    private let sut = SmartInsertService()

    // MARK: - smartInsertComponents

    func test_smartInsertComponents_string_returnsQuotedKeyAndEmptyValue() {
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"name\": \"\"")
        XCTAssertEqual(cursorBack, 1)
    }

    func test_smartInsertComponents_wktString_returnsSameSnippetAsString() {
        let suggestion = AutocompleteSuggestion(name: "created_at", typeHint: "Timestamp", kind: .wktString)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"created_at\": \"\"")
        XCTAssertEqual(cursorBack, 1)
    }

    func test_smartInsertComponents_number_returnsKeyColonSpace() {
        let suggestion = AutocompleteSuggestion(name: "age", typeHint: "int32", kind: .number)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"age\": ")
        XCTAssertEqual(cursorBack, 0)
    }

    func test_smartInsertComponents_bool_returnsKeyColonSpace() {
        let suggestion = AutocompleteSuggestion(name: "active", typeHint: "bool", kind: .bool)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"active\": ")
        XCTAssertEqual(cursorBack, 0)
    }

    func test_smartInsertComponents_message_returnsNestedBraces() {
        let suggestion = AutocompleteSuggestion(name: "addr", typeHint: "Address", kind: .message)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"addr\": {\n  \n}")
        XCTAssertEqual(cursorBack, 2)
    }

    func test_smartInsertComponents_message_withTwoSpaceIndent_usesProperIndentation() {
        let suggestion = AutocompleteSuggestion(name: "addr", typeHint: "Address", kind: .message)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion, lineIndent: "  ")
        XCTAssertEqual(text, "\"addr\": {\n    \n  }")
        XCTAssertEqual(cursorBack, 4)
    }

    func test_smartInsertComponents_message_withFourSpaceIndent_usesProperIndentation() {
        let suggestion = AutocompleteSuggestion(name: "user", typeHint: "User", kind: .message)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion, lineIndent: "    ")
        XCTAssertEqual(text, "\"user\": {\n      \n    }")
        XCTAssertEqual(cursorBack, 6)
    }

    func test_smartInsertComponents_nonMessage_ignoresLineIndent() {
        let suggestion = AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion, lineIndent: "    ")
        XCTAssertEqual(text, "\"name\": \"\"")
        XCTAssertEqual(cursorBack, 1)
    }

    func test_smartInsertComponents_enum_returnsQuotedName() {
        let suggestion = AutocompleteSuggestion(name: "ACTIVE", typeHint: "Status", kind: .enum)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"ACTIVE\"")
        XCTAssertEqual(cursorBack, 0)
    }

    func test_smartInsertComponents_enumField_returnsKeyWithColon() {
        let suggestion = AutocompleteSuggestion(name: "status", typeHint: "Status", kind: .enumField)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"status\": ")
        XCTAssertEqual(cursorBack, 0)
    }

    func test_smartInsertComponents_wktDefault_insertsInsertValue() {
        let suggestion = AutocompleteSuggestion(
            name: "now",
            typeHint: "Timestamp RFC 3339",
            kind: .wktDefault,
            insertValue: "2026-04-09T17:44:56Z")
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"2026-04-09T17:44:56Z\"")
        XCTAssertEqual(cursorBack, 0)
    }

    func test_smartInsertComponents_wktDefault_fallsBackToNameWhenNoInsertValue() {
        let suggestion = AutocompleteSuggestion(name: "0s", typeHint: "Duration", kind: .wktDefault)
        let (text, _) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"0s\"")
    }

    func test_smartInsertComponents_repeated_returnsEmptyArray() {
        let suggestion = AutocompleteSuggestion(name: "tags", typeHint: "string[]", kind: .repeated)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"tags\": []")
        XCTAssertEqual(cursorBack, 1)
    }

    func test_smartInsertComponents_fillDefaults_returnsEmptyString() {
        let suggestion = AutocompleteSuggestion(name: "fillDefaults", typeHint: "", kind: .fillDefaults)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "")
        XCTAssertEqual(cursorBack, 0)
    }

    // MARK: - unclosedBraceCount

    func test_unclosedBraceCount_balanced_returnsZero() {
        XCTAssertEqual(sut.unclosedBraceCount(in: "{\"a\": 1}"), 0)
    }

    func test_unclosedBraceCount_oneOpen_returnsOne() {
        XCTAssertEqual(sut.unclosedBraceCount(in: "{\"a\": 1"), 1)
    }

    func test_unclosedBraceCount_nestedOpen_returnsTwo() {
        XCTAssertEqual(sut.unclosedBraceCount(in: "{\"a\": {\"b\": 1"), 2)
    }

    func test_unclosedBraceCount_bracesInsideString_ignored() {
        XCTAssertEqual(sut.unclosedBraceCount(in: "{\"data\": \"{{{}\"}"), 0)
    }

    func test_unclosedBraceCount_empty_returnsZero() {
        XCTAssertEqual(sut.unclosedBraceCount(in: ""), 0)
    }

    func test_unclosedBraceCount_moreClosed_returnsZero() {
        XCTAssertEqual(sut.unclosedBraceCount(in: "}}"), 0)
    }

    func test_unclosedBraceCount_escapedQuoteInsideString_correctCount() {
        XCTAssertEqual(sut.unclosedBraceCount(in: "{\"key\": \"val\\\"ue\""), 1)
    }

    // MARK: - arrayBracketBalanceInPrefix

    func test_arrayBracketBalanceInPrefix_insideNestedArray_returnsDepth() {
        let s = "{\n  \"names\": [\n    {\n      " as NSString
        let depth = sut.arrayBracketBalanceInPrefix(ns: s, endUTF16: s.length)
        XCTAssertEqual(depth, 1)
    }

    // MARK: - netBraceCountInUTF16Range

    func test_netBraceCountInUTF16Range_objectInsideArray_countsOneOpenBrace() {
        let str = "{\n  \"names\": [\n    {\n      \"id\": \"\""
        let ns = str as NSString
        let openBracket = ns.range(of: "[").location
        let segmentStart = openBracket + 1
        let net = sut.netBraceCountInUTF16Range(
            ns: ns,
            fromUTF16: segmentStart,
            toUTF16: ns.length)
        XCTAssertEqual(net, 1)
    }

    // MARK: - findPartialStringStart

    func test_findPartialStringStart_cursorInsidePartialKey_returnsOpeningQuoteOffset() {
        // `{"num` — cursor at end (position 5); opening `"` is at position 1.
        let ns = "{\"num" as NSString
        let result = sut.findPartialStringStart(in: ns, cursorOffset: ns.length)
        XCTAssertEqual(result, 1)
    }

    func test_findPartialStringStart_cursorAfterCompleteKey_returnsNil() {
        // `{"b"` — cursor at end (position 4); the `"` at 3 closes the string, not opens.
        let ns = "{\"b\"" as NSString
        let result = sut.findPartialStringStart(in: ns, cursorOffset: ns.length)
        XCTAssertNil(result, "Cursor is after a fully closed string — no partial key")
    }

    func test_findPartialStringStart_cursorAtOpeningQuote_returnsItsOffset() {
        // `{"` — cursor right after the opening `"` (position 2).
        let ns = "{\"" as NSString
        let result = sut.findPartialStringStart(in: ns, cursorOffset: ns.length)
        XCTAssertEqual(result, 1)
    }

    func test_findPartialStringStart_cursorAfterStructuralChar_returnsNil() {
        // `{"a": ` — cursor after space; hits `:` during backward scan.
        let ns = "{\"a\": " as NSString
        let result = sut.findPartialStringStart(in: ns, cursorOffset: ns.length)
        XCTAssertNil(result)
    }

    func test_findPartialStringStart_cursorInsideSecondPartialKey_returnsItsStart() {
        // `{"a": 1, "par` — cursor at end; second key starts at index 9.
        let ns = "{\"a\": 1, \"par" as NSString
        let result = sut.findPartialStringStart(in: ns, cursorOffset: ns.length)
        XCTAssertEqual(result, 9)
    }

    func test_findPartialStringStart_emptyCursor_returnsNil() {
        let ns = "" as NSString
        let result = sut.findPartialStringStart(in: ns, cursorOffset: 0)
        XCTAssertNil(result)
    }

    // MARK: - valueStringRange

    func test_valueStringRange_cursorInsideEmptyQuotes_coversBothQuotes() {
        // `{"f": "█"}` — cursor at position 7 (between the two `"`)
        let ns = "{\"f\": \"\"}" as NSString
        let cursor = 7
        let result = sut.valueStringRange(in: ns, cursorOffset: cursor)
        XCTAssertEqual(result, NSRange(location: 6, length: 2), "Should cover both empty quotes")
    }

    func test_valueStringRange_cursorInsidePartialValue_coversFullQuotedToken() {
        // `{"f": "abc█"}` — cursor after `c` (position 10)
        let ns = "{\"f\": \"abc\"}" as NSString
        let cursor = 10
        let result = sut.valueStringRange(in: ns, cursorOffset: cursor)
        XCTAssertEqual(result, NSRange(location: 6, length: 5), "Should cover \"abc\"")
    }

    func test_valueStringRange_cursorAfterColon_returnsNil() {
        // `{"f": █}` — cursor after space, hits `:` during backward scan
        let ns = "{\"f\": }" as NSString
        let cursor = 6
        let result = sut.valueStringRange(in: ns, cursorOffset: cursor)
        XCTAssertNil(result, "No surrounding quotes — nothing to replace")
    }

    func test_valueStringRange_cursorAfterComma_returnsNil() {
        // `{"a": 1,█` — cursor right after comma
        let ns = "{\"a\": 1," as NSString
        let result = sut.valueStringRange(in: ns, cursorOffset: ns.length)
        XCTAssertNil(result)
    }

    // MARK: - isInsideStringLiteral

    func test_isInsideStringLiteral_cursorBetweenQuotes_returnsTrue() {
        // "hello" — offset 3 is inside the string (after opening " h e)
        let ns = "\"hello\"" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 3))
    }

    func test_isInsideStringLiteral_cursorOutsideString_returnsFalse() {
        // {"a": 1} — offset 8 (end) — both quotes are balanced
        let ns = "{\"a\": 1}" as NSString
        XCTAssertFalse(sut.isInsideStringLiteral(in: ns, at: 8))
    }

    func test_isInsideStringLiteral_cursorAfterEscapedQuote_returnsTrue() {
        // "val\"ue" — the \" is an escaped quote, not a string terminator
        // NSString content: "val\"ue"  (indices: 0=" 1=v 2=a 3=l 4=\ 5=" 6=u 7=e 8=")
        let ns = "\"val\\\"ue\"" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 7))
    }

    func test_isInsideStringLiteral_cursorAfterBothEscapedQuotesAroundWord_returnsTrue() {
        // "say \"hi\" please" — cursor at offset 12 (the 'p' of "please")
        // Two escaped quotes surround "hi"; first \" opens, second \" closes the inner word,
        // but both are escaped so neither toggles inString — cursor is still inside outer string.
        // NSString: "  s  a  y  SP \  "  h  i  \  "  SP p  ...
        //           0  1  2  3  4  5  6  7  8  9 10  11 12
        let ns = "\"say \\\"hi\\\" please\"" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 12))
    }

    func test_isInsideStringLiteral_stringValueContainsJsonLikeContent_returnsTrue() {
        // {"a":"{b}"} — offset 7 (the 'b') is inside the string value "{b}"
        // NSString: { " a " : " { b } " }
        //           0 1 2 3 4 5 6 7 8 9 10
        let ns = "{\"a\":\"{b}\"}" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 7))
    }

    // MARK: - isInsideStringLiteral — escape sequence cursor positions

    func test_isInsideStringLiteral_cursorJustBeforeEscapeBackslash_returnsTrue() {
        // "a\"b" — cursor at offset 2 (right before the \, escape not yet started)
        // NSString: "  a  \  "  b  "
        //           0  1  2  3  4  5
        let ns = "\"a\\\"b\"" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 2))
    }

    func test_isInsideStringLiteral_cursorBetweenBackslashAndEscapedQuote_returnsTrue() {
        // "a\"b" — cursor at offset 3 (between \ and the escaped "), still inside
        let ns = "\"a\\\"b\"" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 3))
    }

    func test_isInsideStringLiteral_cursorInsideWordBetweenTwoEscapedQuotePairs_returnsTrue() {
        // "say \"hi\" please" — cursor at offset 8 (the 'i' of "hi"), between both \"
        // NSString: "  s  a  y  SP \  "  h  i  \  " ...
        //           0  1  2  3  4  5  6  7  8  9 10
        let ns = "\"say \\\"hi\\\" please\"" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 8))
    }

    func test_isInsideStringLiteral_cursorBetweenDoubleBackslashes_returnsTrue() {
        // "a\\ b" — \\ is an escaped backslash; cursor at offset 3 (the second \)
        // NSString: "  a  \  \  SP b  "
        //           0  1  2  3  4  5  6
        let ns = "\"a\\\\ b\"" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 3))
    }

    func test_isInsideStringLiteral_cursorAfterDoubleBackslash_returnsTrue() {
        // "a\\ b" — cursor at offset 4 (the space right after \\), still inside the string
        let ns = "\"a\\\\ b\"" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 4))
    }

    func test_isInsideStringLiteral_doubleBackslashThenClosingQuote_cursorAfterClosingQuote_returnsFalse() {
        // "a\\"x — \\ is escaped backslash; the " at index 4 CLOSES the string; x at index 5 is outside
        // NSString: "  a  \  \  "  x
        //           0  1  2  3  4  5
        let ns = "\"a\\\\\"x" as NSString
        XCTAssertFalse(sut.isInsideStringLiteral(in: ns, at: 5))
    }

    func test_isInsideStringLiteral_escapedBackslashThenEscapedQuote_cursorAfterBothSequences_returnsTrue() {
        // "x\\\"y" — \\\" = escaped backslash (\) then escaped quote ("); cursor at offset 6 (y)
        // NSString: "  x  \  \  \  "  y  "
        //           0  1  2  3  4  5  6  7
        let ns = "\"x\\\\\\\"y\"" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 6))
    }

    func test_isInsideStringLiteral_emptyStringLiteral_cursorBetweenQuotes_returnsTrue() {
        // "" — empty JSON string; cursor at offset 1 (between the two quotes)
        let ns = "\"\"" as NSString
        XCTAssertTrue(sut.isInsideStringLiteral(in: ns, at: 1))
    }

    // MARK: - lineIndentation

    func test_lineIndentation_noLeadingWhitespace_returnsEmpty() {
        // {"a": 1} — no leading whitespace on this single line
        let ns = "{\"a\": 1}" as NSString
        XCTAssertEqual(sut.lineIndentation(in: ns, at: 5), "")
    }

    func test_lineIndentation_twoSpaces_returnsTwoSpaces() {
        // "{\n  \"a\": 1}" — cursor at offset 4 (the '"'), line start is 2
        // NSString: { \n SP SP " a ...
        //           0  1  2  3 4 5
        let ns = "{\n  \"a\": 1}" as NSString
        XCTAssertEqual(sut.lineIndentation(in: ns, at: 4), "  ")
    }

    func test_lineIndentation_nestedFourSpaces_returnsFourSpaces() {
        // "{\n    \"a\": 1}" — cursor at offset 6 (the '"'), line start is 2
        // NSString: { \n SP SP SP SP " a ...
        //           0  1  2  3  4  5 6 7
        let ns = "{\n    \"a\": 1}" as NSString
        XCTAssertEqual(sut.lineIndentation(in: ns, at: 6), "    ")
    }

    // MARK: - findBareTextStart

    func test_findBareTextStart_withBareText_returnsStartIndex() {
        let ns = "{dfdf" as NSString
        let result = sut.findBareTextStart(in: ns, cursorOffset: ns.length)
        XCTAssertEqual(result, 1, "Bare text `dfdf` starts at index 1 (after `{`)")
    }

    func test_findBareTextStart_cursorAfterStructural_returnsNil() {
        let ns = "{  " as NSString
        let result = sut.findBareTextStart(in: ns, cursorOffset: ns.length)
        XCTAssertNil(result, "Only whitespace after `{` — no bare text")
    }

    func test_findBareTextStart_cursorAfterQuote_returnsNil() {
        let ns = "{\"" as NSString
        let result = sut.findBareTextStart(in: ns, cursorOffset: ns.length)
        XCTAssertNil(result)
    }

    func test_findBareTextStart_withLeadingWhitespaceThenBareText_returnsNonWhitespaceStart() {
        let ns = "{  abc" as NSString
        let result = sut.findBareTextStart(in: ns, cursorOffset: ns.length)
        XCTAssertEqual(result, 3, "Bare text `abc` starts at index 3 (after `{  `)")
    }

    func test_findBareTextStart_emptyString_returnsNil() {
        let ns = "" as NSString
        let result = sut.findBareTextStart(in: ns, cursorOffset: 0)
        XCTAssertNil(result)
    }

    // MARK: - indentedClosingSuffix

    func test_indentedClosingSuffix_countZero_returnsEmpty() {
        XCTAssertEqual(sut.indentedClosingSuffix(count: 0, baseIndent: "  "), "")
    }

    func test_indentedClosingSuffix_count1_twoSpaceIndent_returnsIndentedBrace() {
        XCTAssertEqual(sut.indentedClosingSuffix(count: 1, baseIndent: "  "), "\n  }")
    }

    func test_indentedClosingSuffix_count2_fourSpaceIndent_returnsTwoIndentedBraces() {
        XCTAssertEqual(sut.indentedClosingSuffix(count: 2, baseIndent: "    "), "\n    }\n  }")
    }

    func test_indentedClosingSuffix_count1_noIndent_returnsUnindentedBrace() {
        XCTAssertEqual(sut.indentedClosingSuffix(count: 1, baseIndent: ""), "\n}")
    }
}
