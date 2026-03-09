import Foundation

public protocol SelectEnvironmentUseCaseProtocol {
    func execute(_ environment: ServerEnvironment?)
}

public final class SelectEnvironmentUseCase: SelectEnvironmentUseCaseProtocol {
    private let repository: EnvironmentRepositoryProtocol

    public init(repository: EnvironmentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(_ environment: ServerEnvironment?) {
        repository.setSelectedId(environment?.id)
    }
}
