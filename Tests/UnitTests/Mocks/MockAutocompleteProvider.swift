import Foundation
@testable import TrueRPCMini

/// Test double for `AutocompleteProviderProtocol`; returns a fixed suggestion list.
struct MockAutocompleteProvider: AutocompleteProviderProtocol {
    let stubSuggestions: [AutocompleteSuggestion]
    let stubValueTypeHint: JsonValueTypeHint?

    init(
        stubSuggestions: [AutocompleteSuggestion] = [],
        stubValueTypeHint: JsonValueTypeHint? = nil)
    {
        self.stubSuggestions = stubSuggestions
        self.stubValueTypeHint = stubValueTypeHint
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

    func valueTypeHint(
        for _: AutocompleteContext,
        rootMessageType _: String,
        in _: ProtoFile)
        async -> JsonValueTypeHint?
    {
        await Task.yield()
        return stubValueTypeHint
    }
}
