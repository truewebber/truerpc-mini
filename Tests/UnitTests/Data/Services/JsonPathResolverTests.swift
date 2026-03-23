import XCTest
@testable import TrueRPCMini

final class JsonPathResolverTests: XCTestCase {
    private let sut = JsonPathResolver()

    // MARK: - Boundary conditions

    func test_resolve_cursorOffsetZero_returnsDefaultContext() {
        let context = sut.resolve(json: "{\"a\": 1}", cursorOffset: 0)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_cursorOffsetExceedsStringLength_clampsToEnd() {
        let json = "{"
        let context = sut.resolve(json: json, cursorOffset: 9999)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_emptyString_returnsDefaultContext() {
        let context = sut.resolve(json: "", cursorOffset: 0)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    // MARK: - Root containers

    func test_resolve_cursorAtRootObject_returnsEmptyPathKeyMode() {
        let json = "{"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_cursorAtRootArray_returnsEmptyPathArrayElementMode() {
        let json = "["
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .arrayElement)
    }

    // MARK: - Object key editing

    func test_resolve_withIncompleteKey_returnsKeyMode() {
        let json = "{\"nam"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_cursorAtSecondKey_returnsKeyMode() {
        // First key fully typed and a second key started.
        let json = "{\"a\": 1, \"b"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_cursorAfterTrailingComma_returnsKeyMode() {
        let json = "{\"a\":1,"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_cursorInsideEscapeInKey_returnsKeyMode() {
        // Cursor inside a key string that contains a backslash-escaped char.
        let json = "{\"ke\\"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    // MARK: - Object value editing

    func test_resolve_cursorAfterColon_returnsEnumValueMode() {
        let json = "{\"a\": "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_cursorInStringValue_returnsEnumValueMode() {
        let json = "{\"a\":\"hel"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_cursorInsideEscapeSequenceInValue_doesNotCrash() {
        let json = "{\"a\":\"x\\"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_cursorInsideNumber_returnsEnumValueMode() {
        let json = "{\"a\": 42"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_cursorInsideNegativeNumber_returnsEnumValueMode() {
        let json = "{\"a\": -3"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_cursorInsideTrueLiteral_returnsEnumValueMode() {
        let json = "{\"a\": tru"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_cursorInsideFalseLiteral_returnsEnumValueMode() {
        let json = "{\"a\": fals"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_cursorInsideNullLiteral_returnsEnumValueMode() {
        let json = "{\"a\": nul"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_afterCompletedTrue_thenComma_returnsKeyMode() {
        let json = "{\"a\": true, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_afterCompletedFalse_thenComma_returnsKeyMode() {
        let json = "{\"a\": false, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_afterCompletedNull_thenComma_returnsKeyMode() {
        let json = "{\"a\": null, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    // MARK: - Nested objects

    func test_resolve_cursorInsideNestedObject_returnsCorrectPath() {
        let json = "{\"user\": {\"nam"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["user"])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_twoLevelNestedValue_returnsPathAndEnumValueMode() {
        let json = "{\"a\": {\"b\": "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["a"])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_deeplyNestedThreeLevels_returnsFullPath() {
        let json = "{\"l1\":{\"l2\":{\"l3\":{"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["l1", "l2", "l3"])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_cursorAfterClosedNestedObject_returnsRootPath() {
        // {"a":{}} — cursor right before the outer closing brace (offset 7).
        let json = "{\"a\":{}}"
        let context = sut.resolve(json: json, cursorOffset: 7)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_afterClosedNestedAndComma_returnsKeyMode() {
        let json = "{\"a\": {}, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    // MARK: - Arrays

    func test_resolve_cursorInsideArrayUnderKey_returnsPathAndArrayMode() {
        let json = "{\"items\": ["
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["items"])
        XCTAssertEqual(context.mode, .arrayElement)
    }

    func test_resolve_cursorInsideNestedArray_returnsArrayElementModeWithPath() {
        let json = "{\"items\":[["
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["items"])
        XCTAssertEqual(context.mode, .arrayElement)
    }

    func test_resolve_cursorAfterCompletedStringInArray_returnsArrayElementMode() {
        // Previously buggy: completing a string in an array left a phantom ObjectFrame on the stack.
        let json = "{\"items\": [\"done\", "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["items"])
        XCTAssertEqual(context.mode, .arrayElement)
    }

    func test_resolve_cursorInsideStringInArray_returnsArrayElementMode() {
        let json = "{\"items\": [\"ab"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["items"])
        XCTAssertEqual(context.mode, .arrayElement)
    }

    func test_resolve_cursorAfterCommaInArray_returnsArrayElementMode() {
        let json = "{\"items\": [1, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["items"])
        XCTAssertEqual(context.mode, .arrayElement)
    }

    func test_resolve_cursorInsideObjectWithinArray_returnsKeyMode() {
        let json = "{\"items\": [{\"na"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["items"])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_multipleCompletedStringsInArray_returnsArrayElementMode() {
        let json = "{\"tags\": [\"foo\", \"bar\", "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["tags"])
        XCTAssertEqual(context.mode, .arrayElement)
    }

    // MARK: - Robustness: missing closing brackets

    func test_resolve_withMissingClosingBrace_doesNotCrash() {
        let json = "{\"a\": 1"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_withMissingClosingBraceInNestedObject_returnsCorrectPath() {
        let json = "{\"a\": {\"b\": 1"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["a"])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_withMissingClosingArray_returnsArrayElementMode() {
        let json = "{\"items\": [1, 2"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["items"])
        XCTAssertEqual(context.mode, .arrayElement)
    }

    func test_resolve_withIncompleteKeyInNestedObject_returnsPathAndKeyMode() {
        let json = "{\"user\": {\"phon"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["user"])
        XCTAssertEqual(context.mode, .key)
    }
}
