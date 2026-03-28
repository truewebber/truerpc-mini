import Foundation
@testable import TrueRPCMini

/// Test double for `AutocompleteProviderProtocol`; returns a fixed suggestion list.
struct MockAutocompleteProvider: AutocompleteProviderProtocol {
    let stubSuggestions: [AutocompleteSuggestion]

    init(stubSuggestions: [AutocompleteSuggestion] = []) {
        self.stubSuggestions = stubSuggestions
    }

    func suggestions(
        for _: AutocompleteContext,
        rootMessageType _: String,
        in _: ProtoFile)
        async -> [AutocompleteSuggestion]
    {
        await Task.yield()
        return stubSuggestions
    }
}
