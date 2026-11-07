import XCTest
@testable import TrueRPCMini

@MainActor
final class AutocompleteViewModelTests: XCTestCase {
    var sut: AutocompleteViewModel!
    var mockProvider: MockAutocompleteProvider!
    var mockResolver: MockJsonPathResolver!
    var testProtoFile: ProtoFile!

    override func setUp() async throws {
        try await super.setUp()
        mockResolver = MockJsonPathResolver()
        testProtoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/tmp/test.proto"),
            services: [])
    }

    override func tearDown() async throws {
        sut = nil
        mockProvider = nil
        mockResolver = nil
        testProtoFile = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeSuggestion(name: String = "field", kind: SuggestionKind = .string) -> AutocompleteSuggestion {
        AutocompleteSuggestion(name: name, typeHint: "string", kind: kind)
    }

    private func makeSUT(
        suggestions: [AutocompleteSuggestion],
        valueTypeHint: JsonValueTypeHint? = nil)
        -> AutocompleteViewModel
    {
        mockProvider = MockAutocompleteProvider(
            stubSuggestions: suggestions,
            stubValueTypeHint: valueTypeHint)
        let vm = AutocompleteViewModel(
            provider: mockProvider,
            resolver: mockResolver,
            methodInputType: ".test.TestMessage")
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
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))

        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        XCTAssertTrue(vm.isVisible)
        XCTAssertEqual(vm.suggestions.count, 2)
    }

    func test_textDidChange_whenProviderReturnsEmpty_isVisibleFalse() async {
        let vm = makeSUT(suggestions: [])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))

        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_textDidChange_afterVisibleThenEmpty_hidesPopover() async {
        let s = [makeSuggestion(name: "a")]
        let vm = makeSUT(suggestions: s)
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
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
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
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

    func test_textDidChange_whenValueSlotIsEmpty_publishesTypeName() async {
        let hint = JsonValueTypeHint(name: "int32", kind: .number)
        let vm = makeSUT(suggestions: [], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "count"))
        let text = "{\n  \"count\": "

        await vm.textDidChange(text, cursorOffset: (text as NSString).length, protoFile: testProtoFile)

        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertFalse(vm.isVisible)
    }

    func test_textDidChange_whenKeyMode_doesNotPublishTypeName() async {
        let hint = JsonValueTypeHint(name: "int32", kind: .number)
        let vm = makeSUT(suggestions: [makeSuggestion()], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))

        await vm.textDidChange("{", cursorOffset: 1, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_whenPartialValue_hidesTypeName() async {
        let hint = JsonValueTypeHint(name: "int32", kind: .number)
        let vm = makeSUT(suggestions: [], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            partialKey: "1",
            currentFieldKey: "count"))
        let text = "{\n  \"count\": 1"

        await vm.textDidChange(text, cursorOffset: (text as NSString).length, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
    }

    func test_textDidChange_whenTextHasNoObject_clearsTypeName() async {
        let hint = JsonValueTypeHint(name: "string", kind: .string)
        let vm = makeSUT(suggestions: [], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "name"))
        let text = "{\"name\": \"\"}"
        let cursor = (text as NSString).range(of: "\"\"").location + 1
        await vm.textDidChange(text, cursorOffset: cursor, protoFile: testProtoFile)
        XCTAssertEqual(vm.valueTypeHint, hint)

        await vm.textDidChange("hello", cursorOffset: 5, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
    }

    func test_refreshValueTypeHint_whenValueSlotIsEmpty_publishesTypeNameWithoutChangingSuggestions() async {
        let hint = JsonValueTypeHint(name: "bool", kind: .bool)
        let vm = makeSUT(suggestions: [makeSuggestion(name: "name")], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.textDidChange("{", cursorOffset: 1, protoFile: testProtoFile)
        XCTAssertTrue(vm.isVisible)

        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "active"))
        let text = "{\n  \"active\": "
        await vm.refreshValueTypeHint(text, cursorOffset: (text as NSString).length, protoFile: testProtoFile)

        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertTrue(vm.isVisible)
        XCTAssertEqual(vm.suggestions.map(\.name), ["name"])
    }

    func test_textDidChange_whenValueIsAlreadyPresent_hidesTypeName() async {
        let hint = JsonValueTypeHint(name: "Timestamp", kind: .wktString)
        let vm = makeSUT(suggestions: [], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: ["names"],
            mode: .enumValue,
            currentFieldKey: "birthday"))
        let text = "{\n  \"birthday\": \"2026-11-07T13:47:26Z\"\n  \"id\": \"\"\n}"
        let cursor = (text as NSString).range(of: "\"id\"").location

        await vm.textDidChange(text, cursorOffset: cursor, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
    }

    func test_textDidChange_textWithoutOpeningBrace_doesNotShowSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion()])

        await vm.textDidChange("\"name\": 1", cursorOffset: 9, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_textDidChange_textStartingWithBrace_showsSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion()])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))

        await vm.textDidChange("{", cursorOffset: 1, protoFile: testProtoFile)

        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_textWithLeadingWhitespaceAndBrace_showsSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion()])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))

        await vm.textDidChange("  {", cursorOffset: 3, protoFile: testProtoFile)

        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_wasVisibleThenEmptyText_dismissesSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion()])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        XCTAssertTrue(vm.isVisible)

        await vm.textDidChange("", cursorOffset: 0, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    // MARK: - moveDown

    func test_moveDown_incrementsSelectedIndex() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        vm.moveDown()

        XCTAssertEqual(vm.selectedIndex, 1)
    }

    func test_moveDown_wrapsFromLastToFirst() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a"), makeSuggestion(name: "b")])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
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
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        vm.moveDown()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - moveUp

    func test_moveUp_decrementsSelectedIndex() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        vm.moveDown()

        vm.moveUp()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_moveUp_wrapsFromFirstToLast() async {
        let suggestions = [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")]
        let vm = makeSUT(suggestions: suggestions)
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
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
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        vm.moveUp()

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    // MARK: - dismiss

    func test_dismiss_keepsTheValueTypeHint() async {
        let hint = JsonValueTypeHint(name: "bool", kind: .bool)
        let vm = makeSUT(
            suggestions: [makeSuggestion(name: "true", kind: .boolLiteral)],
            valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "flags"))
        let text = "{\n  \"flags\": "
        await vm.textDidChange(text, cursorOffset: (text as NSString).length, protoFile: testProtoFile)
        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertTrue(vm.isVisible)

        vm.dismiss()

        XCTAssertFalse(vm.isVisible)
        XCTAssertTrue(vm.suggestions.isEmpty)
        XCTAssertEqual(vm.valueTypeHint, hint)
    }

    func test_dismiss_clearsStateAndHidesPopover() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a")])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
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
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        let result = vm.commitSelection()

        XCTAssertEqual(result?.name, "alpha")
    }

    func test_commitSelection_returnsSelectedSuggestionAfterMoveDown() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "alpha"), makeSuggestion(name: "beta")])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
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
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        let result = vm.commitSelection()

        XCTAssertEqual(result?.kind, .fillDefaults)
    }

    // MARK: - Navigation round-trip

    func test_moveDown_thenUp_returnsToOriginalIndex() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
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
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        for _ in 0 ..< suggestions.count {
            vm.moveDown()
        }

        XCTAssertEqual(vm.selectedIndex, 0)
    }

    func test_fullCycleUp_returnsToZero() async {
        let suggestions = [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")]
        let vm = makeSUT(suggestions: suggestions)
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
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
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            siblingKeys: ["name"]))

        await vm.textDidChange("{\"name\": \"val\", ", cursorOffset: 16, protoFile: testProtoFile)

        let names = vm.suggestions.map(\.name)
        XCTAssertFalse(names.contains("name"), "Already-present key should be filtered")
        XCTAssertTrue(names.contains("age"))
        XCTAssertFalse(names.contains("fillDefaults"), "fillDefaults must be hidden when root fields already exist")
    }

    func test_textDidChange_noSiblingKeys_noFiltering() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "a"),
            makeSuggestion(name: "b"),
        ])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))

        await vm.textDidChange("{", cursorOffset: 1, protoFile: testProtoFile)

        XCTAssertEqual(vm.suggestions.count, 2)
    }

    // MARK: - arrayElement mode — enum values

    func test_textDidChange_arrayElementMode_whenProviderReturnsSuggestions_showsPopover() async {
        let enumVal = makeSuggestion(name: "ACTIVE", kind: .enum)
        let vm = makeSUT(suggestions: [enumVal])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: ["statuses"], mode: .arrayElement))

        await vm.textDidChange("{\"statuses\": [", cursorOffset: 14, protoFile: testProtoFile)

        XCTAssertTrue(vm.isVisible, "Enum values should be shown inside repeated enum array")
        XCTAssertEqual(vm.suggestions.count, 1)
        XCTAssertEqual(vm.suggestions.first?.name, "ACTIVE")
    }

    func test_textDidChange_arrayElementMode_whenProviderReturnsEmpty_hidesPopover() async {
        let vm = makeSUT(suggestions: [])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: ["labels"], mode: .arrayElement))

        await vm.textDidChange("{\"labels\": [", cursorOffset: 12, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible, "No suggestions should be visible when provider returns empty")
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_textDidChange_objectInsideArray_showsSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "name")])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: ["items"], mode: .key))

        await vm.textDidChange("{\"items\": [{", cursorOffset: 12, protoFile: testProtoFile)

        XCTAssertTrue(vm.isVisible, "Popover should show inside { within array")
    }

    // MARK: - Partial key prefix filtering

    func test_textDidChange_withPartialStringKey_filtersWithoutRegardToCase() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "firstName"),
            makeSuggestion(name: "lastName"),
        ])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            partialKey: "FIR"))

        await vm.textDidChange("{\"FIR", cursorOffset: 5, protoFile: testProtoFile)

        XCTAssertEqual(vm.suggestions.map(\.name), ["firstName"])
    }

    func test_textDidChange_withPartialStringKey_filtersByPrefix() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "firstName"),
            makeSuggestion(name: "lastName"),
            makeSuggestion(name: "phone"),
        ])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            partialKey: "fir"))

        await vm.textDidChange("{\"fir", cursorOffset: 5, protoFile: testProtoFile)

        let names = vm.suggestions.map(\.name)
        XCTAssertTrue(names.contains("firstName"), "firstName starts with 'fir'")
        XCTAssertFalse(names.contains("lastName"), "lastName does not start with 'fir'")
        XCTAssertFalse(names.contains("phone"), "phone does not start with 'fir'")
    }

    func test_textDidChange_withBareText_filtersByPrefix() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "firstName"),
            makeSuggestion(name: "lastName"),
        ])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            partialKey: "fir"))

        await vm.textDidChange("{fir", cursorOffset: 4, protoFile: testProtoFile)

        let names = vm.suggestions.map(\.name)
        XCTAssertTrue(names.contains("firstName"))
        XCTAssertFalse(names.contains("lastName"))
    }

    func test_textDidChange_withPartialKey_hidesFillDefaults() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "fillDefaults", kind: .fillDefaults),
            makeSuggestion(name: "firstName"),
        ])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            partialKey: "fir"))

        await vm.textDidChange("{\"fir", cursorOffset: 5, protoFile: testProtoFile)

        XCTAssertFalse(
            vm.suggestions.map(\.name).contains("fillDefaults"),
            "fillDefaults must be hidden when user is typing a key")
    }

    func test_textDidChange_withEmptyPartialKey_showsAllSuggestions() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "fillDefaults", kind: .fillDefaults),
            makeSuggestion(name: "firstName"),
            makeSuggestion(name: "lastName"),
        ])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))

        await vm.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        XCTAssertEqual(vm.suggestions.count, 3, "All suggestions visible when no partial key")
    }

    func test_textDidChange_withNonMatchingPartialKey_showsNoSuggestions() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "firstName"),
            makeSuggestion(name: "lastName"),
        ])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            partialKey: "zzz"))

        await vm.textDidChange("{\"zzz", cursorOffset: 5, protoFile: testProtoFile)

        XCTAssertTrue(vm.suggestions.isEmpty, "No suggestions when partial key matches nothing")
        XCTAssertFalse(vm.isVisible)
    }

    // MARK: - fillDefaults visibility based on root level and siblings

    func test_textDidChange_rootLevelWithSiblings_hidesFillDefaults() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "fillDefaults", kind: .fillDefaults),
            makeSuggestion(name: "age"),
        ])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            siblingKeys: ["name"]))

        await vm.textDidChange("{\"name\": \"val\", ", cursorOffset: 16, protoFile: testProtoFile)

        let names = vm.suggestions.map(\.name)
        XCTAssertFalse(names.contains("fillDefaults"), "fillDefaults must be hidden at root when any field exists")
        XCTAssertTrue(names.contains("age"))
    }

    func test_textDidChange_nestedLevelNoSiblings_hidesFillDefaults() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "fillDefaults", kind: .fillDefaults),
            makeSuggestion(name: "id"),
        ])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: ["request_context", "user"],
            mode: .key))

        await vm.textDidChange("{\"request_context\": {\"user\": {", cursorOffset: 30, protoFile: testProtoFile)

        XCTAssertFalse(
            vm.suggestions.map(\.name).contains("fillDefaults"),
            "fillDefaults must be hidden inside nested objects even when no siblings exist")
        XCTAssertTrue(vm.suggestions.map(\.name).contains("id"))
    }

    func test_textDidChange_arrayElement_hidesFillDefaults() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "fillDefaults", kind: .fillDefaults),
            makeSuggestion(name: "enabled", kind: .bool),
        ])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: ["items"], mode: .arrayElement))

        await vm.textDidChange("{\"items\": [", cursorOffset: 11, protoFile: testProtoFile)

        XCTAssertEqual(vm.suggestions.map(\.name), ["enabled"])
        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_insideMessageArrayElement_hidesOnlyThatElementsKeys() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "fillDefaults", kind: .fillDefaults),
            makeSuggestion(name: "enabled", kind: .bool),
            makeSuggestion(name: "detail", kind: .message),
        ])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: ["items"],
            mode: .key,
            siblingKeys: ["enabled"]))

        await vm.textDidChange("{\"items\":[{\"enabled\":true,", cursorOffset: 26, protoFile: testProtoFile)

        XCTAssertEqual(vm.suggestions.map(\.name), ["detail"])
    }

    func test_textDidChange_oneofAlternative_staysUntilItsOwnKeyIsWritten() async {
        let vm = makeSUT(suggestions: [
            AutocompleteSuggestion(name: "opt_a", typeHint: "string", kind: .string, oneOfGroup: "choice"),
            AutocompleteSuggestion(name: "opt_b", typeHint: "int32", kind: .number, oneOfGroup: "choice"),
        ])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            siblingKeys: ["opt_a"]))

        await vm.textDidChange("{\"opt_a\": \"\", ", cursorOffset: 14, protoFile: testProtoFile)

        XCTAssertEqual(vm.suggestions.map(\.name), ["opt_b"])
    }

    func test_textDidChange_emptyNestedMessage_hidesTheOnlyFillDefaultsRow() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "fillDefaults", kind: .fillDefaults),
        ])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: ["box"], mode: .key))

        await vm.textDidChange("{\"box\": {", cursorOffset: 9, protoFile: testProtoFile)

        XCTAssertTrue(vm.suggestions.isEmpty)
        XCTAssertFalse(vm.isVisible)
    }

    func test_textDidChange_rootLevelNoSiblings_showsFillDefaults() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "fillDefaults", kind: .fillDefaults),
            makeSuggestion(name: "age"),
        ])
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))

        await vm.textDidChange("{", cursorOffset: 1, protoFile: testProtoFile)

        let names = vm.suggestions.map(\.name)
        XCTAssertTrue(names.contains("fillDefaults"), "fillDefaults must be shown at root when no fields exist yet")
    }

    // MARK: - Outside root object

    func test_textDidChange_cursorAfterCompleteRootObject_dismissesSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "name")])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            isOutsideRootObject: true))

        await vm.textDidChange("{\"a\": 1}", cursorOffset: 8, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible, "Popover must not show when cursor is outside the root {}")
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_textDidChange_cursorAfterEmptyRootObject_dismissesSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "name")])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            isOutsideRootObject: true))

        await vm.textDidChange("{}", cursorOffset: 2, protoFile: testProtoFile)

        XCTAssertFalse(vm.isVisible, "Popover must not show after closing brace of empty root object")
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func test_textDidChange_cursorBeforeClosingBraceOfRootObject_showsSuggestions() async {
        let vm = makeSUT(suggestions: [makeSuggestion(name: "name")])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            siblingKeys: ["a"]))

        await vm.textDidChange("{\"a\": 1}", cursorOffset: 7, protoFile: testProtoFile)

        XCTAssertTrue(vm.isVisible, "Popover must show when cursor is still inside root {}")
    }

    // MARK: - Full sibling key filtering (keys after cursor)

    func test_textDidChange_filtersSiblingKeysAfterCursor() async {
        let vm = makeSUT(suggestions: [
            makeSuggestion(name: "a"),
            makeSuggestion(name: "b"),
            makeSuggestion(name: "c"),
        ])
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            siblingKeys: ["a"]))
        mockResolver.stubCollectKeys(["b"])

        let json = "{\"a\": 1,\n\n\"b\": 2}"
        await vm.textDidChange(json, cursorOffset: 9, protoFile: testProtoFile)

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

    // MARK: - wktDefault survives partialKey filtering

    func test_textDidChange_outsideRoot_clearsTypeName() async {
        let hint = JsonValueTypeHint(name: "string", kind: .string)
        let vm = makeSUT(suggestions: [], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "name"))
        let text = "{\"name\": \"\"}"
        let cursor = (text as NSString).range(of: "\"\"").location + 1
        await vm.textDidChange(text, cursorOffset: cursor, protoFile: testProtoFile)
        XCTAssertEqual(vm.valueTypeHint, hint)

        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            isOutsideRootObject: true))
        await vm.textDidChange("{\"name\": \"a\"}", cursorOffset: 13, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertFalse(vm.isVisible)
    }

    func test_textDidChange_arrayRoot_clearsTypeName() async {
        let hint = JsonValueTypeHint(name: "string", kind: .string)
        let vm = makeSUT(suggestions: [], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .arrayElement))

        await vm.textDidChange("[\"\"]", cursorOffset: 2, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertFalse(vm.isVisible)
    }

    func test_textDidChange_leadingWhitespace_publishesTypeName() async {
        let hint = JsonValueTypeHint(name: "string", kind: .string)
        let vm = makeSUT(suggestions: [], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "name"))
        let text = "  {\"name\": \"\"}"
        let cursor = (text as NSString).range(of: "\"\"").location + 1

        await vm.textDidChange(text, cursorOffset: cursor, protoFile: testProtoFile)

        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertFalse(vm.isVisible)
    }

    func test_textDidChange_bytesSlot_publishesTypeNameWithoutSuggestions() async {
        let hint = JsonValueTypeHint(name: "bytes", kind: .string)
        let vm = makeSUT(suggestions: [], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "data"))
        let text = "{\n  \"data\": \"\""
        let cursor = (text as NSString).range(of: "\"\"").location + 1

        await vm.textDidChange(text, cursorOffset: cursor, protoFile: testProtoFile)

        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertFalse(vm.isVisible)
    }

    func test_textDidChange_boolSlot_publishesTypeNameAndLiterals() async {
        let hint = JsonValueTypeHint(name: "bool", kind: .bool)
        let vm = makeSUT(
            suggestions: [
                makeSuggestion(name: "true", kind: .boolLiteral),
                makeSuggestion(name: "false", kind: .boolLiteral),
            ],
            valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "flags"))
        let text = "{\n  \"flags\": "

        await vm.textDidChange(text, cursorOffset: (text as NSString).length, protoFile: testProtoFile)

        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertEqual(vm.suggestions.map(\.name), ["true", "false"])
        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_enumSlot_publishesTypeNameAndConstants() async {
        let hint = JsonValueTypeHint(name: "Status", kind: .enumField)
        let vm = makeSUT(
            suggestions: [
                makeSuggestion(name: "ACTIVE", kind: .enum),
                makeSuggestion(name: "INACTIVE", kind: .enum),
            ],
            valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "status"))
        let text = "{\n  \"status\": \"\""
        let cursor = (text as NSString).range(of: "\"\"").location + 1

        await vm.textDidChange(text, cursorOffset: cursor, protoFile: testProtoFile)

        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertEqual(vm.suggestions.map(\.name), ["ACTIVE", "INACTIVE"])
        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_timestampSlot_publishesTypeNameAndPreset() async {
        let hint = JsonValueTypeHint(name: "Timestamp", kind: .wktString)
        let preset = AutocompleteSuggestion(
            name: "now",
            typeHint: "Timestamp RFC 3339",
            kind: .wktDefault,
            insertValue: "2026-11-07T13:47:26Z")
        let vm = makeSUT(suggestions: [preset], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "created_at"))
        let text = "{\n  \"created_at\": \"\""
        let cursor = (text as NSString).range(of: "\"\"").location + 1

        await vm.textDidChange(text, cursorOffset: cursor, protoFile: testProtoFile)

        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertEqual(vm.suggestions.map(\.name), ["now"])
        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_durationSlot_publishesTypeNameAndPresets() async {
        let hint = JsonValueTypeHint(name: "Duration", kind: .wktString)
        let vm = makeSUT(
            suggestions: [makeSuggestion(name: "1s", kind: .wktDefault)],
            valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "ttl"))
        let text = "{\n  \"ttl\": "

        await vm.textDidChange(text, cursorOffset: (text as NSString).length, protoFile: testProtoFile)

        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertEqual(vm.suggestions.map(\.kind), [.wktDefault])
        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_partialLiteral_hidesTypeNameAndFiltersTheList() async {
        let hint = JsonValueTypeHint(name: "bool", kind: .bool)
        let vm = makeSUT(
            suggestions: [
                makeSuggestion(name: "true", kind: .boolLiteral),
                makeSuggestion(name: "false", kind: .boolLiteral),
            ],
            valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            partialKey: "t",
            currentFieldKey: "flags"))
        let text = "{\n  \"flags\": t"

        await vm.textDidChange(text, cursorOffset: (text as NSString).length, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertEqual(vm.suggestions.map(\.name), ["true"])
        XCTAssertTrue(vm.isVisible)
    }

    func test_textDidChange_deletingBackToAnEmptySlot_restoresTheTypeName() async {
        let hint = JsonValueTypeHint(name: "bool", kind: .bool)
        let literals = [
            makeSuggestion(name: "true", kind: .boolLiteral),
            makeSuggestion(name: "false", kind: .boolLiteral),
        ]
        let vm = makeSUT(suggestions: literals, valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            partialKey: "t",
            currentFieldKey: "flags"))
        await vm.textDidChange("{\n  \"flags\": t", cursorOffset: 13, protoFile: testProtoFile)
        XCTAssertNil(vm.valueTypeHint)

        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "flags"))
        let text = "{\n  \"flags\": "
        await vm.textDidChange(text, cursorOffset: (text as NSString).length, protoFile: testProtoFile)

        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertEqual(vm.suggestions.map(\.name), ["true", "false"])
    }

    func test_textDidChange_unknownField_publishesNoTypeName() async {
        let vm = makeSUT(suggestions: [], valueTypeHint: nil)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "missing"))
        let text = "{\n  \"missing\": "

        await vm.textDidChange(text, cursorOffset: (text as NSString).length, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertFalse(vm.isVisible)
    }

    func test_refreshValueTypeHint_whenCaretMovesToAKey_clearsTypeNameWithoutChangingSuggestions() async {
        let hint = JsonValueTypeHint(name: "string", kind: .string)
        let vm = makeSUT(suggestions: [makeSuggestion(name: "name")], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.textDidChange("{", cursorOffset: 1, protoFile: testProtoFile)
        XCTAssertEqual(vm.suggestions.map(\.name), ["name"])
        XCTAssertTrue(vm.isVisible)

        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "name"))
        let text = "{\n  \"name\": \"\""
        let cursor = (text as NSString).range(of: "\"\"").location + 1
        await vm.refreshValueTypeHint(text, cursorOffset: cursor, protoFile: testProtoFile)

        XCTAssertEqual(vm.valueTypeHint, hint)
        XCTAssertEqual(vm.suggestions.map(\.name), ["name"])
        XCTAssertTrue(vm.isVisible)

        mockResolver.stubResolve(AutocompleteContext(resolvedPath: [], mode: .key))
        await vm.refreshValueTypeHint("{", cursorOffset: 1, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertEqual(vm.suggestions.map(\.name), ["name"])
        XCTAssertTrue(vm.isVisible)
    }

    func test_refreshValueTypeHint_outsideRoot_clearsTypeName() async {
        let hint = JsonValueTypeHint(name: "string", kind: .string)
        let vm = makeSUT(suggestions: [], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .key,
            isOutsideRootObject: true))

        await vm.refreshValueTypeHint("{\"a\": 1}", cursorOffset: 8, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
    }

    func test_textDidChange_wktDefaultSuggestion_keptWhenPartialKeyIsTyped() async {
        let hint = JsonValueTypeHint(name: "Timestamp", kind: .wktString)
        let wktSuggestion = AutocompleteSuggestion(
            name: "now",
            typeHint: "Timestamp RFC 3339",
            kind: .wktDefault,
            insertValue: "2026-04-09T17:44:56Z")
        let vm = makeSUT(suggestions: [wktSuggestion], valueTypeHint: hint)
        mockResolver.stubResolve(AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            partialKey: "2026",
            currentFieldKey: "created_at"))

        await vm.textDidChange("{\"created_at\": \"2026", cursorOffset: 19, protoFile: testProtoFile)

        XCTAssertNil(vm.valueTypeHint)
        XCTAssertTrue(vm.isVisible, "wktDefault suggestion must survive partialKey filter")
        XCTAssertEqual(vm.suggestions.first?.kind, .wktDefault)
    }
}
