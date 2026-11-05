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

    @ViewBuilder
    private var envMenuItems: some View {
        if viewModel.environments.isEmpty {
            Text("No environments saved")
                .foregroundStyle(.secondary)
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
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("No Environment")
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

#if DEBUG
    #Preview("Empty", traits: .fixedLayout(width: 280, height: 44)) {
        GlobalEnvironmentSelectorView(viewModel: PreviewGlobalEnvironments.viewModel(environments: []))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    #Preview("Selected", traits: .fixedLayout(width: 280, height: 44)) {
        GlobalEnvironmentSelectorView(
            viewModel: PreviewGlobalEnvironments.viewModel(selected: .previewLocal))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    #Preview("Long Content", traits: .fixedLayout(width: 280, height: 44)) {
        GlobalEnvironmentSelectorView(
            viewModel: PreviewGlobalEnvironments.viewModel(
                environments: [.previewLongName],
                selected: .previewLongName))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    #Preview("Dark", traits: .fixedLayout(width: 280, height: 44)) {
        GlobalEnvironmentSelectorView(
            viewModel: PreviewGlobalEnvironments.viewModel(selected: .previewStaging))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.background)
            .preferredColorScheme(.dark)
    }
#endif
