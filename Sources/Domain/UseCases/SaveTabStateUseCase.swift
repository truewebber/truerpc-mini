import Foundation

public protocol SaveTabStateUseCaseProtocol {
    func execute(_ states: [EditorTabState])
}

public final class SaveTabStateUseCase: SaveTabStateUseCaseProtocol {
    private let repository: TabPersistenceProtocol

    public init(repository: TabPersistenceProtocol) {
        self.repository = repository
    }

    public func execute(_ states: [EditorTabState]) {
        repository.saveTabStates(states)
    }
}
