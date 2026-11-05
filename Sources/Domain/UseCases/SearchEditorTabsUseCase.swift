import Foundation

/// Filters open editor tabs by name and groups them by proto contract.
public final class SearchEditorTabsUseCase: SearchEditorTabsUseCaseProtocol, Sendable {
    public init() {}

    public func execute(tabs: [EditorTab], query: String) -> [EditorTabGroup] {
        let words = query
            .split { $0.isWhitespace || $0 == "." || $0 == "/" }
            .map(String.init)

        let tabsByPath = Dictionary(grouping: tabs.filter { matches($0, words: words) }, by: \.protoFile.path)

        return tabsByPath
            .compactMap { path, groupTabs in
                groupTabs.first.map {
                    EditorTabGroup(protoFilePath: path, protoFileName: $0.protoFile.name, tabs: groupTabs)
                }
            }
            .sorted { lhs, rhs in
                let nameOrder = lhs.protoFileName.localizedStandardCompare(rhs.protoFileName)
                guard nameOrder == .orderedSame else { return nameOrder == .orderedAscending }

                return lhs.protoFilePath.path.localizedStandardCompare(rhs.protoFilePath.path) == .orderedAscending
            }
    }

    private func matches(_ tab: EditorTab, words: [String]) -> Bool {
        let fields = [tab.methodName, tab.serviceName, tab.protoFile.name]
        return words.allSatisfy { word in
            fields.contains { $0.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }
}
