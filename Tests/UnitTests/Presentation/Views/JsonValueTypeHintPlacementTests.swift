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
}
