import Foundation
@testable import TrueRPCMini

struct MockAutocompleteProvider: AutocompleteProviderProtocol {
    let stubSuggestions: [AutocompleteSuggestion]

    init(stubSuggestions: [AutocompleteSuggestion] = []) {
        self.stubSuggestions = stubSuggestions
    }

    func suggestions(for _: AutocompleteContext, in _: ProtoFile) async -> [AutocompleteSuggestion] {
        await Task.yield()
        return stubSuggestions
    }
}
