import Foundation

public protocol DeleteEnvironmentUseCaseProtocol {
    func execute(id: UUID)
}

public final class DeleteEnvironmentUseCase: DeleteEnvironmentUseCaseProtocol {
    private let repository: EnvironmentRepositoryProtocol

    public init(repository: EnvironmentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(id: UUID) {
        repository.delete(id: id)
    }
}
