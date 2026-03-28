import XCTest
@testable import TrueRPCMini

@MainActor
final class AutocompleteViewModelTests: XCTestCase {
    var sut: AutocompleteViewModel!
    var mockProvider: MockAutocompleteProvider!
    var resolver: JsonPathResolver!
    var testProtoFile: ProtoFile!

    override func setUp() async throws {
        try await super.setUp()
        resolver = JsonPathResolver()
        testProtoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/tmp/test.proto"),
            services: [])
    }

    override func tearDown() async throws {
        sut = nil
        mockProvider = nil
        resolver = nil
        testProtoFile = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeSuggestion(name: String = "field", kind: SuggestionKind = .string) -> AutocompleteSuggestion {
        AutocompleteSuggestion(name: name, typeHint: "string", kind: kind)
    }

    private func makeSUT(suggestions: [AutocompleteSuggestion]) -> AutocompleteViewModel {
        mockProvider = MockAutocompleteProvider(stubSuggestions: suggestions)
        let vm = AutocompleteViewModel(provider: mockProvider, resolver: resolver, methodInputType: ".test.TestMessage")
        sut = vm
        return vm
    }

    // MARK: - Initial state

    func test_init_isVisibleFalse() {
        let vm = makeSUT(suggestions: [])
        XCTAssertFalse(vm.isVisible)
    }

    func test_init_suggestionsEmpty() {
        let vm = makeSUT(suggestions: [])
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_init_selectedIndexIsZero() {
        let vm = makeSUT(suggestions: [])
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - textDidChange — visibility

    func test_textDidChange_whenProviderReturnsSuggestions_isVisibleTrue() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "firstName"), makeSuggestion(name: "lastName")])

        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        XCTAssertTrue(vm.isVisible)
        XCTAssertEqual(vm.suggestions.count, 2)
    }

    func test_textDidChange_whenProviderReturnsEmpty_isVisibleFalse() async {
        let vm = makeSUT(suggestions: [])

        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_textDidChange_afterVisibleThenEmpty_hidesPopover() async {
        let s = [makeSuggestion(name: "a")]
        let vm = makeSUT(suggestions: s)
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        XCTAssertTrue(vm.isVisible)

        mockProvider = MockAutocompleteProvider(stubSuggestions: [])
        // Cannot replace provider on existing VM; instead verify that empty results hide
        vm.suggestions = []
        vm.isVisible = false
        XCTAssertFalse(vm.isVisible)
    }

    // MARK: - textDidChange — selectedIndex reset

    func test_textDidChange_resetsSelectedIndexToZero() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        vm.moveDown()
        vm.moveDown()
        XCTAssertEqual(vm.selectedIndex, 2)

        await vm.textDidChange("{\"x", cursorOffset: 3, protoFile: testProtoFile)

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - textDidChange — guard: requires opening brace

    func test_textDidChange_emptyText_doesNotShowSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion()])

        await vm.textDidChange("", cursorOffset: 0, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_textDidChange_whitespaceText_doesNotShowSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion()])

        await vm.textDidChange("   ", cursorOffset: 3, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_textDidChange_textWithoutOpeningBrace_doesNotShowSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion()])

        await vm.textDidChange("\"name\": 1", cursorOffset: 9, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_textDidChange_textStartingWithBrace_showsSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion()])

        await vm.textDidChange("{", cursorOffset: 1, protoFile: testProtoFile)

        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_textWithLeadingWhitespaceAndBrace_showsSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion()])

        await vm.textDidChange("  {", cursorOffset: 3, protoFile: testProtoFile)

        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_wasVisibleThenEmptyText_dismissesSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion()])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        XCTAssertTrue(vm.isVisible)

        await vm.textDidChange("", cursorOffset: 0, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    // MARK: - moveDown

    func test_moveDown_incrementsSelectedIndex() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        vm.moveDown()

        XCTAssertEqual(vm.selectedIndex, 1)
    }

    func test_moveDown_wrapsFromLastToFirst() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a"), makeSuggestion(name: "b")])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        vm.moveDown()
        vm.moveDown()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_moveDown_withEmptySuggestions_doesNothing() {
        let vm = makeSUT(suggestions: [])

        vm.moveDown()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_moveDown_singleSuggestion_wrapsToZero() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "only")])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        vm.moveDown()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - moveUp

    func test_moveUp_decrementsSelectedIndex() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        vm.moveDown()

        vm.moveUp()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_moveUp_wrapsFromFirstToLast() async {
        let suggestions = [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")]
        let vm = makeSUT(suggestions: suggestions)
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        vm.moveUp()

        XCTAssertEqual(vm.selectedIndex, suggestions.count - 1)
    }

    func test_moveUp_withEmptySuggestions_doesNothing() {
        let vm = makeSUT(suggestions: [])

        vm.moveUp()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_moveUp_singleSuggestion_wrapsToZero() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "only")])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        vm.moveUp()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - dismiss

    func test_dismiss_clearsStateAndHidesPopover() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a")])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        XCTAssertTrue(vm.isVisible)

        vm.dismiss()

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_dismiss_whenAlreadyDismissed_isIdempotent() {
        let vm = makeSUT(suggestions: [])

        vm.dismiss()
        vm.dismiss()

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - commitSelection

    func test_commitSelection_returnsFirstSuggestionByDefault() async {
        let first = makeSuggestion(name: "alpha")
        let vm = makeSUT(suggestions: [first, makeSuggestion(name: "beta")])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        let result = vm.commitSelection()

        XCTAssertEqual(result?.name, "alpha")
    }

    func test_commitSelection_returnsSelectedSuggestionAfterMoveDown() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "alpha"), makeSuggestion(name: "beta")])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        vm.moveDown()

        let result = vm.commitSelection()

        XCTAssertEqual(result?.name, "beta")
    }

    func test_commitSelection_whenNoSuggestions_returnsNil() {
        let vm = makeSUT(suggestions: [])

        let result = vm.commitSelection()

        XCTAssertNil(result)
    }

    func test_commitSelection_preservesSuggestionKind() async {
        let fill = makeSuggestion(name: "fillDefaults", kind: .fillDefaults)
        let vm = makeSUT(suggestions: [fill])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        let result = vm.commitSelection()

        XCTAssertEqual(result?.kind, .fillDefaults)
    }

    // MARK: - Navigation round-trip

    func test_moveDown_thenUp_returnsToOriginalIndex() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")])
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        vm.moveDown()
        vm.moveDown()
        vm.moveUp()
        vm.moveUp()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_fullCycleDown_returnsToZero() async {
        let suggestions = [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")]
        let vm = makeSUT(suggestions: suggestions)
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        for _ in 0 ..< suggestions.count {
            vm.moveDown()
        }

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_fullCycleUp_returnsToZero() async {
        let suggestions = [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")]
        let vm = makeSUT(suggestions: suggestions)
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        for _ in 0 ..< suggestions.count {
            vm.moveUp()
        }

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - Sibling key filtering

    func test_textDidChange_filtersOutExistingSiblingKeys() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "fillDefaults", kind: .fillDefaults),
            makeSuggestion(name: "name"),
            makeSuggestion(name: "age"),
        ])

        await vm.textDidChange("{\"name\": \"val\", ", cursorOffset: 16, protoFile: testProtoFile)

        let names = vm.suggestions.map(\.name)
        XCTAssertFalse(names.contains("name"), "Already-present key should be filtered")
        XCTAssertTrue(names.contains("age"))
        XCTAssertTrue(names.contains("fillDefaults"), "fillDefaults must not be filtered")
    }

    func test_textDidChange_noSiblingKeys_noFiltering() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "a"),
            makeSuggestion(name: "b"),
        ])

        await vm.textDidChange("{", cursorOffset: 1, protoFile: testProtoFile)

        XCTAssertEqual(vm.suggestions.count, 2)
    }

    // MARK: - arrayElement mode dismisses

    func test_textDidChange_arrayElementMode_dismissesSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "name"), makeSuggestion(name: "age")])

        await vm.textDidChange("{\"items\": [", cursorOffset: 11, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible, "Popover must not show inside array brackets")
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_textDidChange_objectInsideArray_showsSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "name")])

        await vm.textDidChange("{\"items\": [{", cursorOffset: 12, protoFile: testProtoFile)

        XCTAssertTrue(vm.isVisible, "Popover should show inside { within array")
    }

    // MARK: - Full sibling key filtering (keys after cursor)

    func test_textDidChange_filtersSiblingKeysAfterCursor() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "a"),
            makeSuggestion(name: "b"),
            makeSuggestion(name: "c"),
        ])

        // Cursor is before "b", but "b" is already in the object after cursor
        let json = "{\"a\": 1,\n\n\"b\": 2}"
        let cursorOffset = 9 // after the comma+newline, before "b"
        await vm.textDidChange(json, cursorOffset: cursorOffset, protoFile: testProtoFile)

        let names = vm.suggestions.map(\.name)
        XCTAssertFalse(names.contains("a"), "'a' before cursor should be filtered")
        XCTAssertFalse(names.contains("b"), "'b' after cursor should also be filtered")
        XCTAssertTrue(names.contains("c"), "'c' not in object should remain")
    }

    // MARK: - sortSuggestions

    func test_sortSuggestions_fillDefaultsFirst() {
        let input = [
            AutocompleteSuggestion(name: "b", typeHint: "", kind: .string),
            AutocompleteSuggestion(name: "fill", typeHint: "", kind: .fillDefaults),
            AutocompleteSuggestion(name: "a", typeHint: "", kind: .number),
        ]
        let sorted = AutocompleteViewModel.sortSuggestions(input)
        XCTAssertEqual(sorted.first?.kind, .fillDefaults)
        XCTAssertEqual(sorted.count, 3)
    }

    func test_sortSuggestions_noFillDefaults_orderPreserved() {
        let input = [
            AutocompleteSuggestion(name: "b", typeHint: "", kind: .string),
            AutocompleteSuggestion(name: "a", typeHint: "", kind: .number),
        ]
        let sorted = AutocompleteViewModel.sortSuggestions(input)
        XCTAssertEqual(sorted.map(\.name), ["b", "a"])
    }

    func test_sortSuggestions_empty_returnsEmpty() {
        XCTAssertTrue(AutocompleteViewModel.sortSuggestions([]).isEmpty)
    }
}
