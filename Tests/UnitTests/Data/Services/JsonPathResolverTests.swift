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

    // MARK: - Negative cursor offset

    func test_resolve_negativeCursorOffset_treatedAsZero() {
        let json = "{\"a\": 1}"
        let context = sut.resolve(json: json, cursorOffset: -5)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    // MARK: - Unicode keys

    func test_resolve_unicodeKey_returnsKeyMode() {
        let json = "{\"名前\": "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    func test_resolve_emojiInKey_returnsKeyMode() {
        let json = "{\"🔑\": "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .enumValue)
    }

    // MARK: - Empty nested objects / arrays

    func test_resolve_emptyNestedObject_cursorAfterInner_returnsRootKeyMode() {
        let json = "{\"a\": {}, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_emptyNestedArray_cursorAfterInner_returnsKeyMode() {
        let json = "{\"a\": [], "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_cursorInsideEmptyNestedObject_returnsKeyMode() {
        let json = "{\"a\": {"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["a"])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_cursorInsideEmptyNestedArray_returnsArrayElementMode() {
        let json = "{\"a\": ["
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["a"])
        XCTAssertEqual(context.mode, .arrayElement)
    }

    // MARK: - Deep nesting with arrays of objects

    func test_resolve_objectInArrayWithNestedKey_returnsNestedPath() {
        let json = "{\"items\": [{\"sub\": {"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["items", "sub"])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_multipleObjectsInArray_secondObject_keyMode() {
        let json = "{\"items\": [{\"a\": 1}, {"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["items"])
        XCTAssertEqual(context.mode, .key)
    }

    // MARK: - Cursor at exact positions

    func test_resolve_cursorAtOpeningQuoteOfKey_returnsKeyMode() {
        let json = "{\"" // cursor right after opening quote
        let context = sut.resolve(json: json, cursorOffset: 2)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_cursorBetweenCommaAndNextKey_returnsKeyMode() {
        let json = "{\"a\": 1,  "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    // MARK: - Completed values then more content

    func test_resolve_afterCompletedStringValue_commaNewKey_returnsKeyMode() {
        let json = "{\"a\": \"hello\", \"b"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_afterCompletedNumberValue_commaNewKey_returnsKeyMode() {
        let json = "{\"x\": 42, \"y"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    // MARK: - Bare text (no container)

    func test_resolve_bareText_noContainer_returnsDefaultContext() {
        let json = "hello"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, [])
        XCTAssertEqual(context.mode, .key)
    }

    // MARK: - Complex real-world JSON

    func test_resolve_multiFieldJSON_cursorInSecondNestedObject() {
        let json = "{\"a\": 1, \"b\": {\"c\": \"val\"}, \"d\": {"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["d"])
        XCTAssertEqual(context.mode, .key)
    }

    func test_resolve_arrayOfArrays_innerArray_returnsArrayElementMode() {
        let json = "{\"matrix\": [["
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["matrix"])
        XCTAssertEqual(context.mode, .arrayElement)
    }

    // MARK: - siblingKeys

    func test_resolve_rootObjectOneKey_siblingKeysContainsThatKey() {
        let json = "{\"name\": \"val\", "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.mode, .key)
        XCTAssertEqual(context.siblingKeys, ["name"])
    }

    func test_resolve_rootObjectTwoKeys_siblingKeysContainsBoth() {
        let json = "{\"a\": 1, \"b\": 2, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.siblingKeys, ["a", "b"])
    }

    func test_resolve_nestedObject_siblingKeysFromInnerScope() {
        let json = "{\"outer\": {\"inner1\": 1, \"inner2\": 2, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.resolvedPath, ["outer"])
        XCTAssertEqual(context.siblingKeys, ["inner1", "inner2"])
    }

    func test_resolve_emptyObject_siblingKeysEmpty() {
        let json = "{"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.mode, .key)
        XCTAssertTrue(context.siblingKeys.isEmpty)
    }

    func test_resolve_arrayContext_siblingKeysEmpty() {
        let json = "{\"items\": ["
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.mode, .arrayElement)
        XCTAssertTrue(context.siblingKeys.isEmpty)
    }

    func test_resolve_objectInsideArray_siblingKeysFromNestedObject() {
        let json = "{\"items\": [{\"x\": 1, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.mode, .key)
        XCTAssertEqual(context.siblingKeys, ["x"])
    }

    // MARK: - partialKey

    func test_resolve_cursorInsideStringKey_partialKeyContainsTypedText() {
        let json = "{\"dfdf"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.mode, .key)
        XCTAssertEqual(context.partialKey, "dfdf")
    }

    func test_resolve_cursorInsideEmptyStringKey_partialKeyIsEmpty() {
        let json = "{\""
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.mode, .key)
        XCTAssertEqual(context.partialKey, "")
    }

    func test_resolve_cursorInsideBareTextKey_partialKeyContainsBareText() {
        let json = "{dfdf"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.mode, .key)
        XCTAssertEqual(context.partialKey, "dfdf")
    }

    func test_resolve_cursorAfterComma_partialKeyIsEmpty() {
        let json = "{\"a\": 1, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.mode, .key)
        XCTAssertEqual(context.partialKey, "")
    }

    func test_resolve_cursorInValuePosition_partialKeyIsEmpty() {
        let json = "{\"a\": "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.mode, .enumValue)
        XCTAssertEqual(context.partialKey, "")
    }

    func test_resolve_bareTextClearedAfterComma_partialKeyIsEmpty() {
        // First bare text then comma then no more text
        let json = "{dfdf, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertEqual(context.mode, .key)
        XCTAssertEqual(context.partialKey, "")
    }

    // MARK: - isOutsideRootObject

    func test_resolve_cursorAfterCompleteRootObject_isOutsideRootObject() {
        let json = "{\"a\": 1}"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertTrue(context.isOutsideRootObject)
    }

    func test_resolve_cursorAfterEmptyRootObject_isOutsideRootObject() {
        let json = "{}"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertTrue(context.isOutsideRootObject)
    }

    func test_resolve_cursorBeforeClosingBrace_notOutsideRootObject() {
        // Offset 7 is just before the final `}` of `{"a": 1}`
        let json = "{\"a\": 1}"
        let context = sut.resolve(json: json, cursorOffset: 7)
        XCTAssertFalse(context.isOutsideRootObject)
    }

    func test_resolve_cursorInsideOpenRoot_notOutsideRootObject() {
        let json = "{"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertFalse(context.isOutsideRootObject)
    }

    func test_resolve_cursorInsideNestedObject_notOutsideRootObject() {
        let json = "{\"a\": {"
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertFalse(context.isOutsideRootObject)
    }

    func test_resolve_cursorAfterClosedNestedButRootStillOpen_notOutsideRootObject() {
        let json = "{\"a\": {}, "
        let context = sut.resolve(json: json, cursorOffset: json.count)
        XCTAssertFalse(context.isOutsideRootObject)
    }

    // MARK: - collectKeysAfterCursor

    func test_collectKeysAfterCursor_findsKeysInSameObject() {
        let json = "{\"a\": 1, \"b\": 2, \"c\": 3}"
        let keys = sut.collectKeysAfterCursor(json: json, cursorOffset: 9) // after "a": 1,
        XCTAssertEqual(keys, ["b", "c"])
    }

    func test_collectKeysAfterCursor_stopsAtClosingBrace() {
        let json = "{\"inner\": 1}, \"outer\": 2}"
        let keys = sut.collectKeysAfterCursor(json: json, cursorOffset: 1) // inside first object
        XCTAssertEqual(keys, ["inner"])
    }

    func test_collectKeysAfterCursor_skipsNestedObjects() {
        let json = "{\"a\": {\"nested\": 1}, \"b\": 2}"
        let keys = sut.collectKeysAfterCursor(json: json, cursorOffset: 1) // right after root {
        XCTAssertEqual(keys, ["a", "b"])
    }

    func test_collectKeysAfterCursor_atEndOfText_returnsEmpty() {
        let json = "{\"a\": 1}"
        let keys = sut.collectKeysAfterCursor(json: json, cursorOffset: json.count)
        XCTAssertTrue(keys.isEmpty)
    }

    func test_collectKeysAfterCursor_handlesEscapedQuotes() {
        let json = "{\"k\\\"ey\": 1, \"b\": 2}"
        let keys = sut.collectKeysAfterCursor(json: json, cursorOffset: 1)
        XCTAssertTrue(keys.contains("b"))
        XCTAssertTrue(keys.contains("k\\\"ey") || keys.contains("k\"ey"))
    }

    func test_collectKeysAfterCursor_emptyObject_returnsEmpty() {
        let json = "{}"
        let keys = sut.collectKeysAfterCursor(json: json, cursorOffset: 1)
        XCTAssertTrue(keys.isEmpty)
    }
}
