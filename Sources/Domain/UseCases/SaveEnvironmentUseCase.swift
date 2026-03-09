import Foundation

public protocol SaveEnvironmentUseCaseProtocol {
    func execute(_ environment: ServerEnvironment)
}

public final class SaveEnvironmentUseCase: SaveEnvironmentUseCaseProtocol {
    private let repository: EnvironmentRepositoryProtocol

    public init(repository: EnvironmentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute(_ environment: ServerEnvironment) {
        repository.save(environment)
    }
}
