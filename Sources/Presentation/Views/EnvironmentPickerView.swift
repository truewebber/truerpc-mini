import SwiftUI

/// View for managing saved server environments (named gRPC endpoint configurations).
public struct EnvironmentPickerView: View {
    @ObservedObject var viewModel: GlobalEnvironmentViewModel
    @State private var isAddSheetPresented = false
    @State private var editingEnvironment: ServerEnvironment?

    public init(viewModel: GlobalEnvironmentViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            viewModel.loadEnvironments()
        }
        .sheet(isPresented: $isAddSheetPresented) {
            EnvironmentFormView(onSave: { env in
                viewModel.saveEnvironment(env)
                isAddSheetPresented = false
            }, onCancel: {
                isAddSheetPresented = false
            })
        }
        .sheet(item: $editingEnvironment) { env in
            EnvironmentFormView(environment: env, onSave: { updated in
                viewModel.saveEnvironment(updated)
                editingEnvironment = nil
            }, onCancel: {
                editingEnvironment = nil
            })
        }
    }

    private var headerView: some View {
        HStack {
            Text("Environments")
                .font(.headline)
            Spacer()
            Button {
                isAddSheetPresented = true
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.environments.isEmpty {
            emptyStateView
        } else {
            environmentsList
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Environments", systemImage: "server.rack")
        } description: {
            Text("Add a named endpoint to quickly switch between servers.")
        } actions: {
            Button("Add…") {
                isAddSheetPresented = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var environmentsList: some View {
        List(viewModel.environments) { env in
            EnvironmentRow(
                environment: env,
                isSelected: viewModel.selectedEnvironment?.id == env.id,
                onSelect: { viewModel.selectEnvironment(env) },
                onEdit: { editingEnvironment = env },
                onDelete: { viewModel.deleteEnvironment(env) })
        }
        .listStyle(.inset)
    }
}

private struct EnvironmentRow: View {
    let environment: ServerEnvironment
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(environment.name)
                            .font(.body)
                        Text(environment.url)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Edit")
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Delete")
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
    #Preview("Empty", traits: .fixedLayout(width: 450, height: 480)) {
        EnvironmentPickerView(viewModel: PreviewGlobalEnvironments.viewModel(environments: []))
    }

    #Preview("List", traits: .fixedLayout(width: 450, height: 480)) {
        EnvironmentPickerView(
            viewModel: PreviewGlobalEnvironments.viewModel(selected: .previewLocal))
    }

    #Preview("Long Content", traits: .fixedLayout(width: 450, height: 480)) {
        EnvironmentPickerView(
            viewModel: PreviewGlobalEnvironments.viewModel(
                environments: [.previewLocal, .previewLongName],
                selected: .previewLongName))
    }

    #Preview("Dark", traits: .fixedLayout(width: 450, height: 480)) {
        EnvironmentPickerView(
            viewModel: PreviewGlobalEnvironments.viewModel(selected: .previewLocal))
            .preferredColorScheme(.dark)
    }
#endif
