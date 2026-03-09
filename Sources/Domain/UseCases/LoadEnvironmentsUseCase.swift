import Foundation

public protocol LoadEnvironmentsUseCaseProtocol {
    func execute() -> [ServerEnvironment]
}

public final class LoadEnvironmentsUseCase: LoadEnvironmentsUseCaseProtocol {
    private let repository: EnvironmentRepositoryProtocol

    public init(repository: EnvironmentRepositoryProtocol) {
        self.repository = repository
    }

    public func execute() -> [ServerEnvironment] {
        repository.getAll()
    }
}
