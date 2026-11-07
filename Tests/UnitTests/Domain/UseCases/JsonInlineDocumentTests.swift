import XCTest
@testable import TrueRPCMini

final class JsonInlineDocumentTests: XCTestCase {
    func test_isInline_compactObject_isTrue() {
        XCTAssertTrue(JsonInlineDocument.isInline("{\"id\":\"\",\"name\":\"\"}"))
    }

    func test_isInline_prettyObject_isFalse() {
        let text = "{\n  \"id\" : \"\",\n  \"name\" : \"\"\n}"

        XCTAssertFalse(JsonInlineDocument.isInline(text))
    }

    func test_isInline_emptyContainers_areFalse() {
        XCTAssertFalse(JsonInlineDocument.isInline("{}"))
        XCTAssertFalse(JsonInlineDocument.isInline("[]"))
        XCTAssertFalse(JsonInlineDocument.isInline("{ }"))
    }

    func test_isInline_commaInsideString_isFalse() {
        let text = "{\n  \"note\" : \"hello, world\"\n}"

        XCTAssertFalse(JsonInlineDocument.isInline(text))
    }

    func test_isInline_twoFieldsOnOneLine_isTrue() {
        let text = "{\n  \"id\": \"\", \"name\": \"\"\n}"

        XCTAssertTrue(JsonInlineDocument.isInline(text))
    }

    func test_isInline_arrayValuesOnOneLine_isTrue() {
        XCTAssertTrue(JsonInlineDocument.isInline("{\n  \"tags\" : [1, 2]\n}"))
    }

    func test_isInline_incompleteObject_isFalse() {
        XCTAssertFalse(JsonInlineDocument.isInline("{\"id\":"))
    }

    func test_pretty_compactObject_returnsPrettyPrinted() {
        let result = JsonInlineDocument.pretty("{\"name\":\"John\"}") { try JsonFormatter().format($0) }

        XCTAssertEqual(result, "{\n  \"name\" : \"John\"\n}")
    }

    func test_pretty_alreadyPretty_returnsNil() {
        let text = "{\n  \"name\" : \"John\"\n}"

        XCTAssertNil(JsonInlineDocument.pretty(text) { try JsonFormatter().format($0) })
    }

    func test_pretty_invalidJson_returnsNil() {
        XCTAssertNil(JsonInlineDocument.pretty("{invalid}") { try JsonFormatter().format($0) })
    }

    func test_pretty_preservesKeyOrder() {
        let result = JsonInlineDocument.pretty("{\"b\":1,\"a\":2}") { try JsonFormatter().format($0) }

        XCTAssertEqual(result, "{\n  \"b\" : 1,\n  \"a\" : 2\n}")
    }

    func test_pretty_keepsCommaAndBraceInsideAString() {
        let result = JsonInlineDocument.pretty("{\"note\":\"hello, } world\"}") { try JsonFormatter().format($0) }

        XCTAssertEqual(result, "{\n  \"note\" : \"hello, } world\"\n}")
    }

    func test_cursor_insideEmptyQuotes_staysInsideTheSameValue() throws {
        let compact = "{\"id\":\"\",\"name\":\"\"}"
        let cursor = (compact as NSString).range(of: "\"\"").location + 1
        let pretty = try XCTUnwrap(JsonInlineDocument.pretty(compact) { try JsonFormatter().format($0) })

        let mapped = JsonInlineDocument.cursor(in: pretty, matching: compact, cursorUTF16: cursor)
        let ns = pretty as NSString
        XCTAssertEqual(ns.character(at: mapped - 1), JsonScanUTF16.quote)
        XCTAssertEqual(ns.character(at: mapped), JsonScanUTF16.quote)
    }

    func test_cursor_afterNumber_staysAfterThatNumber() throws {
        let compact = "{\"b\":1,\"a\":2}"
        let cursor = (compact as NSString).range(of: "1").location + 1
        let pretty = try XCTUnwrap(JsonInlineDocument.pretty(compact) { try JsonFormatter().format($0) })

        let mapped = JsonInlineDocument.cursor(in: pretty, matching: compact, cursorUTF16: cursor)
        let ns = pretty as NSString
        XCTAssertEqual(ns.character(at: mapped - 1), UInt16(UnicodeScalar("1").value))
        XCTAssertEqual(ns.character(at: mapped), JsonScanUTF16.comma)
    }

    func test_expanded_compactObject_isPretty() {
        XCTAssertEqual(JsonInlineDocument.expanded("{\"user\":\"John Doe\"}"), "{\n  \"user\" : \"John Doe\"\n}")
    }

    func test_expanded_alreadyPretty_isUnchanged() {
        let pretty = "{\n  \"user\" : \"John Doe\"\n}"

        XCTAssertEqual(JsonInlineDocument.expanded(pretty), pretty)
    }

    func test_expanded_invalidJson_isUnchanged() {
        XCTAssertEqual(JsonInlineDocument.expanded("{invalid"), "{invalid")
    }
}
