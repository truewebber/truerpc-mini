import Combine
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
    private var cancellables = Set<AnyCancellable>()

    public init(
        saveTabStateUseCase: SaveTabStateUseCaseProtocol,
        restoreTabsUseCase: RestoreTabsUseCaseProtocol)
    {
        self.saveTabStateUseCase = saveTabStateUseCase
        self.restoreTabsUseCase = restoreTabsUseCase
        setupTabChangeObservation()
    }

    private func setupTabChangeObservation() {
        $tabs
            .flatMap { tabViewModels in
                Publishers.MergeMany(tabViewModels.map(\.objectWillChange))
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.saveTabs() }
            }
            .store(in: &cancellables)
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

    /// Switches tabs using the given environment to custom URL mode with that env's address
    public func handleEnvironmentDeleted(_ environment: ServerEnvironment) {
        for tab in tabs where tab.tabEnvironment?.id == environment.id {
            tab.useCustomUrl(environment.url)
        }
    }

    /// Refreshes all tabs bound to the updated environment so their URL and TLS state reflect the new config
    public func handleEnvironmentUpdated(_ environment: ServerEnvironment) {
        for tab in tabs where tab.tabEnvironment?.id == environment.id {
            tab.selectTabEnvironment(environment)
        }
    }

    public func restoredStates() -> [EditorTabState] {
        restoreTabsUseCase.execute()
    }

    private func saveTabs() {
        let states = tabs.map(\.currentTabState)
        saveTabStateUseCase.execute(states)
    }
}
