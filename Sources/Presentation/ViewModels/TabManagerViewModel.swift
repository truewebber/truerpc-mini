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

    /// Closes a tab. When it was selected, selects the tab to its right, or to its left when it was the last one.
    public func removeTab(id: UUID) {
        removeTabs { $0.id == id }
    }

    public func closeSelectedTab() {
        guard let selectedTabId else { return }

        removeTab(id: selectedTabId)
    }

    /// Closes every tab except the given one and selects it.
    public func removeOtherTabs(keeping id: UUID) {
        guard tabs.contains(where: { $0.editorTab.id == id }) else { return }

        selectedTabId = id
        removeTabs { $0.id != id }
    }

    /// Closes the tabs after the given one. Selects the given tab when the selected tab was closed.
    public func removeTabsToTheRight(of id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.editorTab.id == id }) else { return }

        let laterIDs = Set(tabs[(index + 1)...].map(\.editorTab.id))
        if let selectedTabId, laterIDs.contains(selectedTabId) {
            self.selectedTabId = id
        }
        removeTabs { laterIDs.contains($0.id) }
    }

    /// Closes every tab opened from the given proto contract.
    public func removeTabs(inProtoFileAt protoFilePath: URL) {
        let path = protoFilePath.standardizedFileURL
        removeTabs { $0.protoFile.path.standardizedFileURL == path }
    }

    public func selectTab(id: UUID?) {
        selectedTabId = id
    }

    /// Selects the tab to the right of the selected one, wrapping around to the first tab.
    public func selectNextTab() {
        selectTab(offsetFromSelection: 1)
    }

    /// Selects the tab to the left of the selected one, wrapping around to the last tab.
    public func selectPreviousTab() {
        selectTab(offsetFromSelection: -1)
    }

    /// Selects an open tab for the method. Prefers the selected tab when the method is open more than once.
    /// - Returns: `false` when no tab shows the method.
    public func selectExistingTab(methodName: String, serviceName: String, protoFilePath: URL) -> Bool {
        let path = protoFilePath.standardizedFileURL
        let matches: (EditorTab) -> Bool = {
            $0.methodName == methodName
                && $0.serviceName == serviceName
                && $0.protoFile.path.standardizedFileURL == path
        }
        if let selectedTab, matches(selectedTab.editorTab) {
            return true
        }
        guard let tab = tabs.first(where: { matches($0.editorTab) }) else { return false }

        selectedTabId = tab.editorTab.id
        return true
    }

    private func selectTab(offsetFromSelection offset: Int) {
        guard !tabs.isEmpty else { return }

        let currentIndex = tabs.firstIndex { $0.editorTab.id == selectedTabId } ?? (offset > 0 ? -1 : tabs.count)
        let nextIndex = (currentIndex + offset + tabs.count) % tabs.count
        selectedTabId = tabs[nextIndex].editorTab.id
    }

    private func removeTabs(where shouldRemove: (EditorTab) -> Bool) {
        let removedIDs = Set(tabs.lazy.map(\.editorTab).filter(shouldRemove).map(\.id))
        guard !removedIDs.isEmpty else { return }

        if let selectedTabId, let selectedIndex = tabs.firstIndex(where: { $0.editorTab.id == selectedTabId }),
           removedIDs.contains(selectedTabId)
        {
            let isKept: (EditorTabViewModel) -> Bool = { !removedIDs.contains($0.editorTab.id) }
            let neighbor = tabs[selectedIndex...].first(where: isKept) ?? tabs[..<selectedIndex].last(where: isKept)
            self.selectedTabId = neighbor?.editorTab.id
        }
        tabs.removeAll { removedIDs.contains($0.editorTab.id) }
        saveTabs()
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

extension TabManagerViewModel: TabSwitcherDataSource {
    public var editorTabs: [EditorTab] {
        tabs.map(\.editorTab)
    }
}
