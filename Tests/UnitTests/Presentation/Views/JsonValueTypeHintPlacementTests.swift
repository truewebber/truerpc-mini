import XCTest
@testable import TrueRPCMini

final class JsonValueTypeHintPlacementTests: XCTestCase {
    func test_shouldShow_whenCursorIsAfterColon_isTrue() {
        let text = "{\n  \"age\": "

        XCTAssertTrue(showsHint(in: text, mode: .enumValue, currentFieldKey: "age"))
    }

    func test_shouldShow_whenNumberHasStarted_isFalse() {
        let text = "{\n  \"age\": 1"

        XCTAssertFalse(showsHint(in: text, mode: .enumValue, currentFieldKey: "age"))
    }

    func test_shouldShow_whenCursorIsInsideEmptyQuotes_isTrue() {
        let text = "{\"name\": \"\"}"
        let cursor = (text as NSString).range(of: "\"\"").location + 1

        XCTAssertTrue(showsHint(in: text, cursorUTF16: cursor, mode: .enumValue, currentFieldKey: "name"))
    }

    func test_shouldShow_whenStringHasACharacter_isFalse() {
        let text = "{\"name\": \"a\"}"
        let cursor = (text as NSString).range(of: "a").location + 1

        XCTAssertFalse(showsHint(in: text, cursorUTF16: cursor, mode: .enumValue, currentFieldKey: "name"))
    }

    func test_shouldShow_whenCursorIsInsideEmptyBrackets_isTrue() {
        let text = "{\"labels\": []}"
        let cursor = (text as NSString).range(of: "]").location

        XCTAssertTrue(showsHint(in: text, cursorUTF16: cursor, mode: .arrayElement))
    }

    func test_shouldShow_whenCursorIsAfterCommaInArray_isTrue() {
        let text = "{\"labels\": [\"a\", ]}"
        let cursor = (text as NSString).range(of: "]").location

        XCTAssertTrue(showsHint(in: text, cursorUTF16: cursor, mode: .arrayElement))
    }

    func test_shouldShow_whenModeIsKey_isFalse() {
        let text = "{\n  "

        XCTAssertFalse(showsHint(in: text, mode: .key))
    }

    func test_shouldShow_whenPartialValueIsNotEmpty_isFalse() {
        let text = "{\n  \"age\": "

        XCTAssertFalse(showsHint(in: text, mode: .enumValue, partialKey: "1", currentFieldKey: "age"))
    }

    func test_shouldShow_whenTimestampIsFilled_beforeNextField_isFalse() {
        let text = "{\n  \"birthday\": \"2026-11-07T13:47:26Z\"\n  \"id\": \"\"\n}"
        let cursor = (text as NSString).range(of: "\"id\"").location

        XCTAssertFalse(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_shouldShow_whenTimestampIsFilled_onTheSameLineAsTheNextField_isFalse() {
        let text = "{\"birthday\": \"2026-11-07T13:47:26Z\", \"id\": \"\"}"
        let cursor = (text as NSString).range(of: "\", \"id\"").location + 1

        XCTAssertFalse(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_shouldShow_whenCursorIsInsideFilledString_isFalse() {
        let text = "{\"birthday\": \"2026-11-07T13:47:26Z\"}"
        let cursor = (text as NSString).range(of: "2026").location + 2

        XCTAssertFalse(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_shouldShow_whenNumberIsFilled_isFalse() {
        let text = "{\"count\": 12, \"next\": 1}"
        let cursor = (text as NSString).range(of: "12").location + 2

        XCTAssertFalse(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_shouldShow_whenCursorSitsBeforeFilledNumber_isFalse() {
        let text = "{\"count\": 12}"
        let cursor = (text as NSString).range(of: "12").location

        XCTAssertFalse(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_shouldShow_whenBoolIsFilled_isFalse() {
        let text = "{\"active\": true, \"next\": 1}"
        let cursor = (text as NSString).range(of: "true").location + 4

        XCTAssertFalse(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_shouldShow_whenNullIsFilled_isFalse() {
        let text = "{\"note\": null, \"next\": 1}"
        let cursor = (text as NSString).range(of: "null").location + 4

        XCTAssertFalse(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_shouldShow_whenEnumValueIsFilled_isFalse() {
        let text = "{\"status\": \"ACTIVE\", \"next\": 1}"
        let cursor = (text as NSString).range(of: "ACTIVE").location + 6

        XCTAssertFalse(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_shouldShow_whenObjectIsFilled_isFalse() {
        let text = "{\"settings\": {}, \"next\": 1}"
        let cursor = (text as NSString).range(of: "{}").location + 2

        XCTAssertFalse(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_shouldShow_whenArrayValueIsFilled_isFalse() {
        let text = "{\"labels\": [\"a\"], \"next\": 1}"
        let cursor = (text as NSString).range(of: "]").location + 1

        XCTAssertFalse(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_shouldShow_whenEmptyTimestampQuotes_isTrue() {
        let text = "{\"birthday\": \"\"}"
        let cursor = (text as NSString).range(of: "\"\"").location + 1

        XCTAssertTrue(showsResolvedHint(in: text, cursorUTF16: cursor))
    }

    func test_blockingCharacter_onOneLine_isTheNextField() {
        let text = "{\"id\": \"\", \"name\": \"\"}"
        let cursor = (text as NSString).range(of: "\"\"").location + 1

        XCTAssertEqual(
            JsonValueTypeHintPlacement.blockingCharacterUTF16(in: text, cursorUTF16: cursor),
            (text as NSString).range(of: "\"name\"").location)
    }

    func test_blockingCharacter_whenNextFieldStartsOnTheNextLine_isThatField() {
        let text = "{\n  \"id\": \"\"\n  \"name\": \"\"\n}"
        let cursor = (text as NSString).range(of: "\"\"").location + 1

        XCTAssertEqual(
            JsonValueTypeHintPlacement.blockingCharacterUTF16(in: text, cursorUTF16: cursor),
            (text as NSString).range(of: "\"name\"").location)
    }

    func test_blockingCharacter_whenLineEndsAfterTheEmptyValue_isNil() {
        let text = "{\n  \"count\": \n}"
        let cursor = (text as NSString).range(of: ": ").location + 2

        XCTAssertNil(JsonValueTypeHintPlacement.blockingCharacterUTF16(in: text, cursorUTF16: cursor))
    }

    func test_anchor_insideEmptyQuotes_isAfterTheComma() {
        let text = "{\n  \"id\" : \"\",\n  \"name\" : \"\"\n}"
        let cursor = (text as NSString).range(of: "\"\"").location + 1
        let comma = (text as NSString).range(of: ",").location

        XCTAssertEqual(
            JsonValueTypeHintPlacement.anchor(in: text, cursorUTF16: cursor),
            .afterCharacter(comma))
    }

    func test_anchor_insideEmptyQuotesWithoutComma_isTheClosingQuote() {
        let text = "{\n  \"name\" : \"\"\n}"
        let closingQuote = (text as NSString).range(of: "\"\"").location + 1

        XCTAssertEqual(
            JsonValueTypeHintPlacement.anchor(in: text, cursorUTF16: closingQuote),
            .afterCharacter(closingQuote))
    }

    func test_anchor_insideEmptyBrackets_isAfterTheBracket() {
        let text = "{\n  \"labels\" : []\n}"
        let cursor = (text as NSString).range(of: "[]").location + 1

        XCTAssertEqual(
            JsonValueTypeHintPlacement.anchor(in: text, cursorUTF16: cursor),
            .afterCharacter(cursor))
    }

    func test_anchor_afterColon_isTheCaret() {
        let text = "{\n  \"count\" : \n}"
        let cursor = (text as NSString).range(of: ": ").location + 2

        XCTAssertEqual(JsonValueTypeHintPlacement.anchor(in: text, cursorUTF16: cursor), .caret)
    }

    func test_anchor_insideEmptyBracketsWithComma_isTheComma() {
        let text = "{\n  \"labels\" : [],\n  \"name\" : \"\"\n}"
        let cursor = (text as NSString).range(of: "[]").location + 1
        let comma = (text as NSString).range(of: ",").location

        XCTAssertEqual(
            JsonValueTypeHintPlacement.anchor(in: text, cursorUTF16: cursor),
            .afterCharacter(comma))
    }

    func test_anchor_whenCommaIsOnTheNextLine_staysOnTheClosingQuote() {
        let text = "{\n  \"id\" : \"\"\n  ,\n  \"name\" : \"\"\n}"
        let closingQuote = (text as NSString).range(of: "\"\"").location + 1
        let cursor = closingQuote

        XCTAssertEqual(
            JsonValueTypeHintPlacement.anchor(in: text, cursorUTF16: cursor),
            .afterCharacter(closingQuote))
    }

    func test_shouldShow_whenQuotesContainASpace_isFalse() {
        let text = "{\"name\": \" \"}"
        let cursor = (text as NSString).range(of: "\" \"").location + 2

        XCTAssertFalse(showsHint(in: text, cursorUTF16: cursor, mode: .enumValue, currentFieldKey: "name"))
    }

    func test_shouldShow_whenCaretIsInsideEmptyObject_isFalse() {
        let text = "{\"settings\": {}}"
        let cursor = (text as NSString).range(of: "{}").location + 1

        XCTAssertFalse(showsHint(in: text, cursorUTF16: cursor, mode: .enumValue, currentFieldKey: "settings"))
    }

    func test_shouldShow_whenCaretIsInsideFilledObject_isFalse() {
        let text = "{\"settings\": {\"enabled\": true}}"
        let cursor = (text as NSString).range(of: "true").location

        XCTAssertFalse(showsHint(in: text, cursorUTF16: cursor, mode: .enumValue, currentFieldKey: "enabled"))
    }

    func test_shouldShow_whenArrayElementQuotesAreEmpty_isTrue() {
        let text = "{\"labels\": [\"\"]}"
        let cursor = (text as NSString).range(of: "[\"\"]").location + 2

        XCTAssertTrue(showsHint(in: text, cursorUTF16: cursor, mode: .arrayElement))
    }

    func test_shouldShow_whenCaretIsInsideFilledArrayElement_isFalse() {
        let text = "{\"labels\": [\"a\"]}"
        let cursor = (text as NSString).range(of: "a").location + 1

        XCTAssertFalse(showsHint(in: text, cursorUTF16: cursor, mode: .arrayElement))
    }

    func test_shouldShow_betweenCommaAndNextKey_isFalse() {
        let text = "{\"id\": \"\", \"name\": \"\"}"
        let cursor = (text as NSString).range(of: "\"name\"").location

        XCTAssertFalse(showsHint(in: text, cursorUTF16: cursor, mode: .enumValue, currentFieldKey: "id"))
    }

    func test_blockingCharacter_afterEmptyBrackets_isTheNextField() {
        let text = "{\"labels\": [], \"name\": \"\"}"
        let cursor = (text as NSString).range(of: "[]").location + 1

        XCTAssertEqual(
            JsonValueTypeHintPlacement.blockingCharacterUTF16(in: text, cursorUTF16: cursor),
            (text as NSString).range(of: "\"name\"").location)
    }

    private func showsHint(
        in text: String,
        cursorUTF16: Int? = nil,
        mode: AutocompleteMode,
        partialKey: String = "",
        currentFieldKey: String? = nil)
        -> Bool
    {
        JsonValueTypeHintPlacement.shouldShow(
            context: AutocompleteContext(
                resolvedPath: [],
                mode: mode,
                partialKey: partialKey,
                currentFieldKey: currentFieldKey),
            text: text,
            cursorUTF16: cursorUTF16 ?? (text as NSString).length)
    }

    private func showsResolvedHint(in text: String, cursorUTF16: Int) -> Bool {
        let context = JsonPathResolver().resolve(json: text, cursorOffset: cursorUTF16)
        return JsonValueTypeHintPlacement.shouldShow(
            context: context,
            text: text,
            cursorUTF16: cursorUTF16)
    }
}
