import XCTest
@testable import TrueRPCMini

/// Sorting logic moved to AutocompleteViewModel; these tests now validate it there.
final class AutocompletePopoverViewTests: XCTestCase {
    // MARK: - Helpers

    private func makeSuggestion(name: String, kind: SuggestionKind) -> AutocompleteSuggestion {
        AutocompleteSuggestion(name: name, typeHint: "hint", kind: kind)
    }

    // MARK: - sortSuggestions — count preservation

    func test_sortSuggestions_preservesCount() {
        let suggestions = [
            makeSuggestion(name: "fieldA", kind: .string),
            makeSuggestion(name: "fieldB", kind: .number),
            makeSuggestion(name: "fieldC", kind: .bool),
        ]
        let sorted = AutocompleteViewModel.sortSuggestions(suggestions)
        XCTAssertEqual(sorted.count, suggestions.count)
    }

    // MARK: - sortSuggestions — order without fillDefaults

    func test_sortSuggestions_withoutFillDefaults_preservesOriginalOrder() {
        let first = makeSuggestion(name: "alpha", kind: .string)
        let second = makeSuggestion(name: "beta", kind: .number)
        let third = makeSuggestion(name: "gamma", kind: .bool)
        let sorted = AutocompleteViewModel.sortSuggestions([first, second, third])
        XCTAssertEqual(sorted[0].name, "alpha")
        XCTAssertEqual(sorted[1].name, "beta")
        XCTAssertEqual(sorted[2].name, "gamma")
    }

    // MARK: - sortSuggestions — fillDefaults first

    func test_sortSuggestions_fillDefaultsMovedToFront() {
        let suggestions = [
            makeSuggestion(name: "fieldA", kind: .string),
            makeSuggestion(name: "fillAll", kind: .fillDefaults),
            makeSuggestion(name: "fieldB", kind: .message),
        ]
        let sorted = AutocompleteViewModel.sortSuggestions(suggestions)
        XCTAssertEqual(sorted.first?.kind, .fillDefaults)
        XCTAssertEqual(sorted.first?.name, "fillAll")
    }

    func test_sortSuggestions_nonFillDefaultsOrderPreservedAfterFillDefaults() {
        let suggestions = [
            makeSuggestion(name: "zulu", kind: .number),
            makeSuggestion(name: "fill", kind: .fillDefaults),
            makeSuggestion(name: "alpha", kind: .string),
        ]
        let sorted = AutocompleteViewModel.sortSuggestions(suggestions)
        XCTAssertEqual(sorted[0].kind, .fillDefaults)
        XCTAssertEqual(sorted[1].name, "zulu")
        XCTAssertEqual(sorted[2].name, "alpha")
    }

    // MARK: - sortSuggestions — edge cases

    func test_sortSuggestions_emptyArray_returnsEmpty() {
        let sorted = AutocompleteViewModel.sortSuggestions([])
        XCTAssertTrue(sorted.isEmpty)
    }

    func test_sortSuggestions_onlyFillDefaults_returnsSingle() {
        let suggestions = [makeSuggestion(name: "fill", kind: .fillDefaults)]
        let sorted = AutocompleteViewModel.sortSuggestions(suggestions)
        XCTAssertEqual(sorted.count, 1)
        XCTAssertEqual(sorted[0].kind, .fillDefaults)
    }

    func test_sortSuggestions_multipleFillDefaults_allBeforeOthers() {
        let suggestions = [
            makeSuggestion(name: "field", kind: .string),
            makeSuggestion(name: "fill1", kind: .fillDefaults),
            makeSuggestion(name: "fill2", kind: .fillDefaults),
        ]
        let sorted = AutocompleteViewModel.sortSuggestions(suggestions)
        XCTAssertEqual(sorted[0].kind, .fillDefaults)
        XCTAssertEqual(sorted[1].kind, .fillDefaults)
        XCTAssertEqual(sorted[2].kind, .string)
    }

    func test_sortSuggestions_singleNonFillDefaults_returnsUnchanged() {
        let suggestions = [makeSuggestion(name: "onlyField", kind: .message)]
        let sorted = AutocompleteViewModel.sortSuggestions(suggestions)
        XCTAssertEqual(sorted.count, 1)
        XCTAssertEqual(sorted[0].name, "onlyField")
    }

    func test_sortSuggestions_fillDefaultsAlreadyFirst_orderUnchanged() {
        let suggestions = [
            makeSuggestion(name: "fill", kind: .fillDefaults),
            makeSuggestion(name: "a", kind: .string),
            makeSuggestion(name: "b", kind: .number),
        ]
        let sorted = AutocompleteViewModel.sortSuggestions(suggestions)
        XCTAssertEqual(sorted[0].name, "fill")
        XCTAssertEqual(sorted[1].name, "a")
        XCTAssertEqual(sorted[2].name, "b")
    }

    // MARK: - sortSuggestions — all suggestion kinds represented

    func test_sortSuggestions_allKindsMixed_fillDefaultsFirst() {
        let suggestions = [
            makeSuggestion(name: "msg", kind: .message),
            makeSuggestion(name: "str", kind: .string),
            makeSuggestion(name: "num", kind: .number),
            makeSuggestion(name: "boo", kind: .bool),
            makeSuggestion(name: "enm", kind: .enum),
            makeSuggestion(name: "rep", kind: .repeated),
            makeSuggestion(name: "fill", kind: .fillDefaults),
        ]
        let sorted = AutocompleteViewModel.sortSuggestions(suggestions)
        XCTAssertEqual(sorted[0].kind, .fillDefaults)
        XCTAssertEqual(sorted.count, 7)
        let nonFillNames = sorted.dropFirst().map(\.name)
        XCTAssertEqual(nonFillNames, ["msg", "str", "num", "boo", "enm", "rep"])
    }
}
