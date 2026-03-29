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

    func test_smartInsertComponents_enum_returnsQuotedName() {
        let suggestion = AutocompleteSuggestion(name: "ACTIVE", typeHint: "Status", kind: .enum)
        let (text, cursorBack) = sut.smartInsertComponents(for: suggestion)
        XCTAssertEqual(text, "\"ACTIVE\"")
        XCTAssertEqual(cursorBack, 0)
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
}
