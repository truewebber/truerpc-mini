import Foundation
import SwiftUI

/// Singleton ViewModel that owns global environment state.
/// Persists the selected environment across sheet openings and app restarts.
@MainActor
public class GlobalEnvironmentViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var environments: [ServerEnvironment] = []
    @Published public var selectedEnvironment: ServerEnvironment?

    // MARK: - Dependencies

    private let loadEnvironmentsUseCase: LoadEnvironmentsUseCaseProtocol
    private let saveEnvironmentUseCase: SaveEnvironmentUseCaseProtocol
    private let deleteEnvironmentUseCase: DeleteEnvironmentUseCaseProtocol
    private let selectEnvironmentUseCase: SelectEnvironmentUseCaseProtocol
    private let getSelectedEnvironmentUseCase: GetSelectedEnvironmentUseCaseProtocol

    // MARK: - Initialization

    public init(
        loadEnvironmentsUseCase: LoadEnvironmentsUseCaseProtocol,
        saveEnvironmentUseCase: SaveEnvironmentUseCaseProtocol,
        deleteEnvironmentUseCase: DeleteEnvironmentUseCaseProtocol,
        selectEnvironmentUseCase: SelectEnvironmentUseCaseProtocol,
        getSelectedEnvironmentUseCase: GetSelectedEnvironmentUseCaseProtocol)
    {
        self.loadEnvironmentsUseCase = loadEnvironmentsUseCase
        self.saveEnvironmentUseCase = saveEnvironmentUseCase
        self.deleteEnvironmentUseCase = deleteEnvironmentUseCase
        self.selectEnvironmentUseCase = selectEnvironmentUseCase
        self.getSelectedEnvironmentUseCase = getSelectedEnvironmentUseCase

        loadEnvironments()
        selectedEnvironment = getSelectedEnvironmentUseCase.execute()
    }

    // MARK: - Public Methods

    /// Loads all environments from storage
    public func loadEnvironments() {
        environments = loadEnvironmentsUseCase.execute()
    }

    /// Sets and persists the global environment selection
    public func selectEnvironment(_ environment: ServerEnvironment) {
        selectedEnvironment = environment
        selectEnvironmentUseCase.execute(environment)
    }

    /// Clears the global environment selection
    public func clearSelection() {
        selectedEnvironment = nil
        selectEnvironmentUseCase.execute(nil)
    }

    /// Saves (creates or updates) an environment and reloads the list
    public func saveEnvironment(_ environment: ServerEnvironment) {
        saveEnvironmentUseCase.execute(environment)
        loadEnvironments()
    }

    /// Deletes an environment. Clears selection if the deleted env was selected.
    public func deleteEnvironment(_ environment: ServerEnvironment) {
        if selectedEnvironment?.id == environment.id {
            selectedEnvironment = nil
            selectEnvironmentUseCase.execute(nil)
        }
        deleteEnvironmentUseCase.execute(id: environment.id)
        loadEnvironments()
    }
}
