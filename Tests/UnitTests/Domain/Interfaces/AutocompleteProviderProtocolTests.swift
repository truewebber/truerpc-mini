import Foundation
import XCTest
@testable import TrueRPCMini

final class AutocompleteProviderProtocolTests: XCTestCase {
    func test_mockAutocompleteProvider_conformsToProtocol() {
        let mock = MockAutocompleteProvider()
        let provider: AutocompleteProviderProtocol = mock
        XCTAssertNotNil(provider as? MockAutocompleteProvider)
    }

    func test_mockAutocompleteProvider_returnsStubbedSuggestions() async {
        let suggestionID = UUID()
        let stub = [
            AutocompleteSuggestion(
                id: suggestionID,
                name: "field_a",
                typeHint: "string",
                kind: .string,
                oneOfGroup: nil),
        ]
        let mock = MockAutocompleteProvider(stubSuggestions: stub)
        let context = AutocompleteContext(resolvedPath: ["root"], mode: .key)
        let proto = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/tmp/test.proto"),
            services: [])

        let result = await mock.suggestions(for: context, rootMessageType: ".test.Message", in: proto)

        XCTAssertEqual(result, stub)
    }
}
