#if DEBUG

    import Foundation

    /// Fixed autocomplete provider used only when the app is launched with `--uitesting`.
    /// Returns deterministic suggestions so XCUITests can assert on known row counts and labels.
    final class UITestAutocompleteProvider: AutocompleteProviderProtocol, Sendable {
        func suggestions(
            for context: AutocompleteContext,
            rootMessageType _: String,
            in _: ProtoFile)
            -> [AutocompleteSuggestion]
        {
            switch context.mode {
            case .key:
                rootKeySuggestions(path: context.resolvedPath, siblingKeys: context.siblingKeys)
            case .enumValue:
                enumSuggestions()
            case .arrayElement:
                arrayElementSuggestions(path: context.resolvedPath)
            }
        }

        // MARK: - Fixtures

        private func rootKeySuggestions(path: [String], siblingKeys: Set<String>) -> [AutocompleteSuggestion] {
            let fields: [AutocompleteSuggestion] = if path == ["address"] {
                [
                    AutocompleteSuggestion(name: "street", typeHint: "string", kind: .string),
                    AutocompleteSuggestion(name: "city", typeHint: "string", kind: .string),
                ]
            } else {
                [
                    AutocompleteSuggestion(name: "(fill defaults)", typeHint: "all fields", kind: .fillDefaults),
                    AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string),
                    AutocompleteSuggestion(name: "age", typeHint: "int32", kind: .number),
                    AutocompleteSuggestion(name: "active", typeHint: "bool", kind: .bool),
                    AutocompleteSuggestion(name: "address", typeHint: "Address", kind: .message),
                    AutocompleteSuggestion(name: "tags", typeHint: "string", kind: .repeated),
                    AutocompleteSuggestion(name: "status", typeHint: "Status", kind: .enum),
                ]
            }
            return fields.filter { $0.kind == .fillDefaults || !siblingKeys.contains($0.name) }
        }

        private func enumSuggestions() -> [AutocompleteSuggestion] {
            [
                AutocompleteSuggestion(name: "ACTIVE", typeHint: "Status", kind: .enum),
                AutocompleteSuggestion(name: "INACTIVE", typeHint: "Status", kind: .enum),
            ]
        }

        private func arrayElementSuggestions(path _: [String]) -> [AutocompleteSuggestion] {
            [
                AutocompleteSuggestion(name: "name", typeHint: "string", kind: .string),
                AutocompleteSuggestion(name: "age", typeHint: "int32", kind: .number),
            ]
        }
    }

#endif
