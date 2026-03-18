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

    /// Called when an environment is deleted; tabs can switch to custom URL using the deleted env's address
    public var onEnvironmentDeleted: ((ServerEnvironment) -> Void)?

    /// Called when an existing environment is updated so open tabs can refresh their TLS state
    public var onEnvironmentUpdated: ((ServerEnvironment) -> Void)?

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
        // Load deferred to loadEnvironments() — called from view .task to avoid blocking App init.
    }

    // MARK: - Public Methods

    /// Loads all environments from storage and restores the selected environment.
    /// Call from view .task/.onAppear — do not run during App init to avoid blocking main thread.
    public func loadEnvironments() {
        environments = loadEnvironmentsUseCase.execute()
        selectedEnvironment = getSelectedEnvironmentUseCase.execute()
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

    /// Saves (creates or updates) an environment and reloads the list.
    /// When updating an existing environment, notifies `onEnvironmentUpdated` so open tabs can refresh.
    public func saveEnvironment(_ environment: ServerEnvironment) {
        let isUpdate = environments.contains { $0.id == environment.id }
        saveEnvironmentUseCase.execute(environment)
        loadEnvironments()
        if isUpdate {
            onEnvironmentUpdated?(environment)
        }
    }

    /// Deletes an environment. Clears selection if the deleted env was selected.
    /// Notifies onEnvironmentDeleted so tabs using it can switch to custom URL.
    public func deleteEnvironment(_ environment: ServerEnvironment) {
        if selectedEnvironment?.id == environment.id {
            selectedEnvironment = nil
            selectEnvironmentUseCase.execute(nil)
        }
        deleteEnvironmentUseCase.execute(id: environment.id)
        onEnvironmentDeleted?(environment)
        loadEnvironments()
    }
}
