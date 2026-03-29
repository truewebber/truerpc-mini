import XCTest
@testable import TrueRPCMini

final class JsonFormatterTests: XCTestCase {
    private let sut = JsonFormatter()

    func test_format_validCompactJson_returnsPrettyPrinted() throws {
        let result = try sut.format("{\"name\":\"John\"}")
        XCTAssertEqual(result, "{\n  \"name\" : \"John\"\n}")
    }

    func test_format_alreadyFormatted_isIdempotent() throws {
        let input = "{\"name\":\"John\"}"
        let first = try sut.format(input)
        let second = try sut.format(first)
        XCTAssertEqual(first, second)
    }

    func test_format_smartQuotes_normalisesBeforeFormat() throws {
        // Left " (U+201C) and right " (U+201D) around key and value
        let input = "{\u{201C}name\u{201D}:\u{201C}John\u{201D}}"
        let result = try sut.format(input)
        XCTAssertEqual(result, "{\n  \"name\" : \"John\"\n}")
    }

    func test_format_emptyString_returnsEmpty() throws {
        XCTAssertEqual(try sut.format(""), "")
    }

    func test_format_emptyObject_returnsEmptyObject() throws {
        XCTAssertEqual(try sut.format("{}"), "{}")
    }

    func test_format_emptyObjectWithSpaces_returnsEmptyObject() throws {
        XCTAssertEqual(try sut.format("{ }"), "{}")
    }

    func test_format_stringValueContainingEscapedJson_preservesStringValue() throws {
        let result = try sut.format("{\"a\":\"{escaped}\"}")
        XCTAssertEqual(result, "{\n  \"a\" : \"{escaped}\"\n}")
    }

    func test_format_invalidJson_throwsInvalidJsonError() throws {
        XCTAssertThrowsError(try sut.format("{invalid}")) { error in
            guard case JsonFormatterError.invalidJSON = error else {
                XCTFail("Expected JsonFormatterError.invalidJSON, got \(error)")
                return
            }
        }
    }
}
