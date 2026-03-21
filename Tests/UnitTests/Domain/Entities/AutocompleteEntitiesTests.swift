import Foundation
import XCTest
@testable import TrueRPCMini

final class AutocompleteEntitiesTests: XCTestCase {
    func test_autocompleteContext_equality_sameValues_isEqual() {
        let context = AutocompleteContext(resolvedPath: ["a", "b"], mode: .key)
        let same = AutocompleteContext(resolvedPath: ["a", "b"], mode: .key)
        XCTAssertEqual(context, same)
    }

    func test_autocompleteContext_equality_differentPath_notEqual() {
        let a = AutocompleteContext(resolvedPath: ["a"], mode: .key)
        let b = AutocompleteContext(resolvedPath: ["b"], mode: .key)
        XCTAssertNotEqual(a, b)
    }

    func test_autocompleteSuggestion_equality_differentIds_notEqual() {
        let id1 = UUID()
        let id2 = UUID()
        let first = AutocompleteSuggestion(
            id: id1,
            name: "foo",
            typeHint: "string",
            kind: .string,
            oneOfGroup: nil)
        let second = AutocompleteSuggestion(
            id: id2,
            name: "foo",
            typeHint: "string",
            kind: .string,
            oneOfGroup: nil)
        XCTAssertNotEqual(first, second)
    }

    func test_suggestionKind_allSevenCasesExist() {
        let kinds: [SuggestionKind] = [
            .message,
            .string,
            .number,
            .bool,
            .enum,
            .repeated,
            .fillDefaults,
        ]
        XCTAssertEqual(Set(kinds).count, 7)
    }
}
