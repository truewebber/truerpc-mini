import Foundation
import SwiftUI

/// ViewModel for managing saved server environments and the currently selected endpoint
@MainActor
public final class EnvironmentPickerViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var environments: [ServerEnvironment] = []
    @Published public var selectedEnvironment: ServerEnvironment?

    // MARK: - Dependencies

    private let loadEnvironmentsUseCase: LoadEnvironmentsUseCaseProtocol
    private let saveEnvironmentUseCase: SaveEnvironmentUseCaseProtocol
    private let deleteEnvironmentUseCase: DeleteEnvironmentUseCaseProtocol

    // MARK: - Initialization

    public init(
        loadEnvironmentsUseCase: LoadEnvironmentsUseCaseProtocol,
        saveEnvironmentUseCase: SaveEnvironmentUseCaseProtocol,
        deleteEnvironmentUseCase: DeleteEnvironmentUseCaseProtocol)
    {
        self.loadEnvironmentsUseCase = loadEnvironmentsUseCase
        self.saveEnvironmentUseCase = saveEnvironmentUseCase
        self.deleteEnvironmentUseCase = deleteEnvironmentUseCase
    }

    // MARK: - Public Methods

    /// Loads all environments from storage
    public func loadEnvironments() {
        environments = loadEnvironmentsUseCase.execute()
    }

    /// Saves (creates or updates) an environment and reloads the list
    public func saveEnvironment(_ environment: ServerEnvironment) {
        saveEnvironmentUseCase.execute(environment)
        loadEnvironments()
    }

    /// Deletes an environment and reloads the list. Clears selection if the deleted env was selected.
    public func deleteEnvironment(_ environment: ServerEnvironment) {
        if selectedEnvironment?.id == environment.id {
            selectedEnvironment = nil
        }
        deleteEnvironmentUseCase.execute(id: environment.id)
        loadEnvironments()
    }

    /// Sets the currently active environment
    public func selectEnvironment(_ environment: ServerEnvironment) {
        selectedEnvironment = environment
    }
}
