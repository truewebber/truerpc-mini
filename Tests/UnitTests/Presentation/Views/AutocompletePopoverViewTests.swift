import XCTest
@testable import TrueRPCMini

final class AutocompletePopoverViewTests: XCTestCase {
    // MARK: - Helpers

    private func makeSuggestion(name: String, kind: SuggestionKind) -> AutocompleteSuggestion {
        AutocompleteSuggestion(name: name, typeHint: "hint", kind: kind)
    }

    // MARK: - test_rowCount_matchesSuggestionsCount

    func test_rowCount_matchesSuggestionsCount() {
        let suggestions = [
            makeSuggestion(name: "fieldA", kind: .string),
            makeSuggestion(name: "fieldB", kind: .number),
            makeSuggestion(name: "fieldC", kind: .bool),
        ]
        let sorted = AutocompletePopoverView.sortSuggestions(suggestions)
        XCTAssertEqual(sorted.count, suggestions.count)
    }

    // MARK: - test_selectedRow_indexMatchesViewModel

    func test_selectedRow_indexMatchesViewModel() {
        let first = makeSuggestion(name: "alpha", kind: .string)
        let second = makeSuggestion(name: "beta", kind: .number)
        let suggestions = [first, second]
        let sorted = AutocompletePopoverView.sortSuggestions(suggestions)
        XCTAssertEqual(sorted[0].name, first.name)
        XCTAssertEqual(sorted[1].name, second.name)
    }

    // MARK: - test_fillDefaultsSuggestion_appearsFirst

    func test_fillDefaultsSuggestion_appearsFirst() {
        let suggestions = [
            makeSuggestion(name: "fieldA", kind: .string),
            makeSuggestion(name: "fillAll", kind: .fillDefaults),
            makeSuggestion(name: "fieldB", kind: .message),
        ]
        let sorted = AutocompletePopoverView.sortSuggestions(suggestions)
        XCTAssertEqual(sorted.first?.kind, .fillDefaults)
    }
}
