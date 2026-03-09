import Foundation

public protocol RestoreTabsUseCaseProtocol {
    func execute() -> [EditorTabState]
}

public final class RestoreTabsUseCase: RestoreTabsUseCaseProtocol {
    private let repository: TabPersistenceProtocol

    public init(repository: TabPersistenceProtocol) {
        self.repository = repository
    }

    public func execute() -> [EditorTabState] {
        repository.getTabStates()
    }
}
