import Foundation
import SwiftUI

/// ViewModel for managing the list of editor tabs and their persistence
@MainActor
public final class TabManagerViewModel: ObservableObject {
    @Published public private(set) var tabs: [EditorTabViewModel] = []
    @Published public var selectedTabId: UUID?

    public var selectedTab: EditorTabViewModel? {
        guard let id = selectedTabId else { return nil }

        return tabs.first { $0.editorTab.id == id }
    }

    private let saveTabStateUseCase: SaveTabStateUseCaseProtocol
    private let restoreTabsUseCase: RestoreTabsUseCaseProtocol

    public init(
        saveTabStateUseCase: SaveTabStateUseCaseProtocol,
        restoreTabsUseCase: RestoreTabsUseCaseProtocol)
    {
        self.saveTabStateUseCase = saveTabStateUseCase
        self.restoreTabsUseCase = restoreTabsUseCase
    }

    public func addTab(_ viewModel: EditorTabViewModel) {
        tabs.append(viewModel)
        selectedTabId = viewModel.editorTab.id
        saveTabs()
    }

    public func removeTab(id: UUID) {
        tabs.removeAll { $0.editorTab.id == id }
        if selectedTabId == id {
            selectedTabId = tabs.first?.editorTab.id
        }
        saveTabs()
    }

    public func selectTab(id: UUID?) {
        selectedTabId = id
    }

    public func restoredStates() -> [EditorTabState] {
        restoreTabsUseCase.execute()
    }

    private func saveTabs() {
        let states = tabs.map { EditorTabState(editorTab: $0.editorTab) }
        saveTabStateUseCase.execute(states)
    }
}
