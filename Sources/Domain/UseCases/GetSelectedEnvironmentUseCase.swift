import Foundation

public protocol GetSelectedEnvironmentUseCaseProtocol {
    func execute() -> ServerEnvironment?
}

public final class GetSelectedEnvironmentUseCase: GetSelectedEnvironmentUseCaseProtocol {
    private let repository: EnvironmentRepositoryProtocol

    public init(repository: EnvironmentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() -> ServerEnvironment? {
        guard let selectedId = repository.getSelectedId() else { return nil }

        return repository.getAll().first { $0.id == selectedId }
    }
}
