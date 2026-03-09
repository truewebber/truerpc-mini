import SwiftUI

/// Compact toolbar control for selecting the global active environment.
/// Shows all saved environments in a Menu; also opens the full EnvironmentPickerView.
public struct GlobalEnvironmentSelectorView: View {
    @ObservedObject var viewModel: GlobalEnvironmentViewModel
    @State private var isManageSheetPresented = false

    public init(viewModel: GlobalEnvironmentViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Menu {
            envMenuItems
            Divider()
            Button("Manage Environments\u{2026}") {
                isManageSheetPresented = true
            }
        } label: {
            menuLabel
        }
        .menuStyle(.borderlessButton)
        .sheet(isPresented: $isManageSheetPresented) {
            EnvironmentPickerView(viewModel: viewModel)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var envMenuItems: some View {
        if viewModel.environments.isEmpty {
            Text("No environments saved")
                .foregroundColor(.secondary)
        } else {
            ForEach(viewModel.environments) { env in
                Button {
                    viewModel.selectEnvironment(env)
                } label: {
                    Label {
                        Text("\(env.name) — \(env.url)")
                    } icon: {
                        if viewModel.selectedEnvironment?.id == env.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if viewModel.selectedEnvironment != nil {
                Divider()
                Button("None") {
                    viewModel.clearSelection()
                }
            }
        }
    }

    private var menuLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "server.rack")
            if let selected = viewModel.selectedEnvironment {
                Text(selected.name)
            } else {
                Text("No Environment")
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

#if DEBUG
    struct GlobalEnvironmentSelectorView_Previews: PreviewProvider {
        static var previews: some View {
            GlobalEnvironmentSelectorView(viewModel: PreviewGlobalEnvironmentViewModel())
                .padding()
        }
    }

    @MainActor
    private final class PreviewGlobalEnvironmentViewModel: GlobalEnvironmentViewModel {
        init() {
            super.init(
                loadEnvironmentsUseCase: PreviewLoadUseCase(),
                saveEnvironmentUseCase: PreviewNoOpSave(),
                deleteEnvironmentUseCase: PreviewNoOpDelete(),
                selectEnvironmentUseCase: PreviewNoOpSelect(),
                getSelectedEnvironmentUseCase: PreviewNoOpGetSelected())
        }
    }

    private final class PreviewLoadUseCase: LoadEnvironmentsUseCaseProtocol {
        func execute() -> [ServerEnvironment] {
            [
                ServerEnvironment(name: "Local", host: "localhost", port: 50051),
                ServerEnvironment(name: "Staging", host: "staging.example.com", port: 443),
            ]
        }
    }

    private final class PreviewNoOpSave: SaveEnvironmentUseCaseProtocol {
        func execute(_: ServerEnvironment) {}
    }

    private final class PreviewNoOpDelete: DeleteEnvironmentUseCaseProtocol {
        func execute(id _: UUID) {}
    }

    private final class PreviewNoOpSelect: SelectEnvironmentUseCaseProtocol {
        func execute(_: ServerEnvironment?) {}
    }

    private final class PreviewNoOpGetSelected: GetSelectedEnvironmentUseCaseProtocol {
        func execute() -> ServerEnvironment? { nil }
    }
#endif
