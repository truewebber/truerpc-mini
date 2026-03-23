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

    private func makeSuggestion(name: String = "field") -> AutocompleteSuggestion {
        AutocompleteSuggestion(name: name, typeHint: "string", kind: .string)
    }

    // MARK: - textDidChange

    func test_textDidChange_whenProviderReturnsSuggestions_isVisibleTrue() async {
        // Given
        let suggestions = [makeSuggestion(name: "firstName"), makeSuggestion(name: "lastName")]
        mockProvider = MockAutocompleteProvider(stubSuggestions: suggestions)
        sut = AutocompleteViewModel(provider: mockProvider, resolver: resolver)

        // When
        await sut.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        // Then
        XCTAssertTrue(sut.isVisible)
        XCTAssertEqual(sut.suggestions.count, 2)
    }

    func test_textDidChange_whenProviderReturnsEmpty_isVisibleFalse() async {
        // Given
        mockProvider = MockAutocompleteProvider(stubSuggestions: [])
        sut = AutocompleteViewModel(provider: mockProvider, resolver: resolver)

        // When
        await sut.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        // Then
        XCTAssertFalse(sut.isVisible)
        XCTAssertTrue(sut.suggestions.isEmpty)
    }

    func test_textDidChange_resetsSelectedIndexToZero() async {
        // Given
        let suggestions = [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")]
        mockProvider = MockAutocompleteProvider(stubSuggestions: suggestions)
        sut = AutocompleteViewModel(provider: mockProvider, resolver: resolver)

        // Pre-condition: advance selection
        await sut.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        sut.moveDown()
        sut.moveDown()
        XCTAssertEqual(sut.selectedIndex, 2)

        // When: new text change arrives
        await sut.textDidChange("{\"x", cursorOffset: 3, protoFile: testProtoFile)

        // Then
        XCTAssertEqual(sut.selectedIndex, 0)
    }

    // MARK: - moveDown

    func test_moveDown_incrementsSelectedIndex() async {
        // Given
        let suggestions = [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")]
        mockProvider = MockAutocompleteProvider(stubSuggestions: suggestions)
        sut = AutocompleteViewModel(provider: mockProvider, resolver: resolver)
        await sut.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        // When
        sut.moveDown()

        // Then
        XCTAssertEqual(sut.selectedIndex, 1)
    }

    func test_moveDown_wrapsFromLastToFirst() async {
        // Given
        let suggestions = [makeSuggestion(name: "a"), makeSuggestion(name: "b")]
        mockProvider = MockAutocompleteProvider(stubSuggestions: suggestions)
        sut = AutocompleteViewModel(provider: mockProvider, resolver: resolver)
        await sut.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        // When
        sut.moveDown() // index = 1
        sut.moveDown() // wraps to 0

        // Then
        XCTAssertEqual(sut.selectedIndex, 0)
    }

    // MARK: - moveUp

    func test_moveUp_decrementsSelectedIndex() async {
        // Given
        let suggestions = [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")]
        mockProvider = MockAutocompleteProvider(stubSuggestions: suggestions)
        sut = AutocompleteViewModel(provider: mockProvider, resolver: resolver)
        await sut.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        sut.moveDown() // index = 1

        // When
        sut.moveUp() // index = 0

        // Then
        XCTAssertEqual(sut.selectedIndex, 0)
    }

    func test_moveUp_wrapsFromFirstToLast() async {
        // Given
        let suggestions = [makeSuggestion(name: "a"), makeSuggestion(name: "b"), makeSuggestion(name: "c")]
        mockProvider = MockAutocompleteProvider(stubSuggestions: suggestions)
        sut = AutocompleteViewModel(provider: mockProvider, resolver: resolver)
        await sut.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)

        // When: moveUp from index 0 wraps to last
        sut.moveUp()

        // Then
        XCTAssertEqual(sut.selectedIndex, suggestions.count - 1)
    }

    // MARK: - dismiss

    func test_dismiss_clearsStateAndHidesPopover() async {
        // Given
        let suggestions = [makeSuggestion(name: "a")]
        mockProvider = MockAutocompleteProvider(stubSuggestions: suggestions)
        sut = AutocompleteViewModel(provider: mockProvider, resolver: resolver)
        await sut.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        XCTAssertTrue(sut.isVisible)

        // When
        sut.dismiss()

        // Then
        XCTAssertFalse(sut.isVisible)
        XCTAssertTrue(sut.suggestions.isEmpty)
    }

    // MARK: - commitSelection

    func test_commitSelection_returnsCurrentlySelectedSuggestion() async {
        // Given
        let first = makeSuggestion(name: "alpha")
        let second = makeSuggestion(name: "beta")
        mockProvider = MockAutocompleteProvider(stubSuggestions: [first, second])
        sut = AutocompleteViewModel(provider: mockProvider, resolver: resolver)
        await sut.textDidChange("{\"", cursorOffset: 2, protoFile: testProtoFile)
        sut.moveDown() // select second

        // When
        let result = sut.commitSelection()

        // Then
        XCTAssertEqual(result?.name, "beta")
    }

    func test_commitSelection_whenNoSuggestions_returnsNil() {
        // Given
        mockProvider = MockAutocompleteProvider(stubSuggestions: [])
        sut = AutocompleteViewModel(provider: mockProvider, resolver: resolver)

        // When
        let result = sut.commitSelection()

        // Then
        XCTAssertNil(result)
    }
}
