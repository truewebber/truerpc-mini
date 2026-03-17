import SwiftUI
import UniformTypeIdentifiers

/// View for managing saved server environments (named gRPC endpoint configurations)
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

    // MARK: - Subviews

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

    private var contentView: some View {
        Group {
            if viewModel.environments.isEmpty {
                emptyStateView
            } else {
                environmentsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No environments")
                .font(.headline)
            Text("Add a named endpoint to quickly switch between servers")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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

// MARK: - EnvironmentRow

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
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(environment.name)
                            .font(.body)
                        Text(environment.url)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - EnvironmentFormView

/// Sheet for creating or editing a ServerEnvironment
struct EnvironmentFormView: View {
    @State private var name: String
    @State private var host: String
    @State private var portText: String
    @State private var tlsConfig: TLSConfiguration

    private let existingId: UUID?
    let onSave: (ServerEnvironment) -> Void
    let onCancel: () -> Void

    init(
        environment: ServerEnvironment? = nil,
        onSave: @escaping (ServerEnvironment) -> Void,
        onCancel: @escaping () -> Void)
    {
        self.existingId = environment?.id
        _name = State(initialValue: environment?.name ?? "")
        _host = State(initialValue: environment?.host ?? "")
        _portText = State(initialValue: environment.map { String($0.port) } ?? "")
        _tlsConfig = State(initialValue: environment?.tlsConfiguration ?? .defaults)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var port: Int? {
        Int(portText)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !host.trimmingCharacters(in: .whitespaces).isEmpty
            && port != nil
    }

    private var tlsModeBinding: Binding<TLSMode> {
        Binding(
            get: { tlsConfig.isTLSEnabled ? .tls : .plaintext },
            set: { tlsConfig.isTLSEnabled = $0 == .tls })
    }

    private var certificateContentTypes: [UTType] {
        [
            UTType(filenameExtension: "pem"),
            UTType(filenameExtension: "crt"),
            UTType(filenameExtension: "cer"),
            UTType(filenameExtension: "key"),
            .data,
        ].compactMap(\.self)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(existingId == nil ? "New Environment" : "Edit Environment")
                    .font(.headline)
                Spacer()
            }
            .padding()
            Divider()
            Form {
                Section("Connection") {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    TextField("Host", text: $host)
                        .textFieldStyle(.roundedBorder)
                    TextField("Port", text: $portText)
                        .textFieldStyle(.roundedBorder)
                }
                Section("Security") {
                    Picker("Mode", selection: tlsModeBinding) {
                        Text("Plaintext").tag(TLSMode.plaintext)
                        Text("TLS").tag(TLSMode.tls)
                    }
                    .pickerStyle(.segmented)

                    if tlsConfig.isTLSEnabled {
                        Toggle("Allow Insecure (Skip Verify)", isOn: $tlsConfig.allowInsecure)
                        SecurityScopedFilePickerButton(
                            label: "Custom CA Certificate",
                            placeholder: "None",
                            url: $tlsConfig.customCAURL,
                            contentTypes: certificateContentTypes)
                        SecurityScopedFilePickerButton(
                            label: "Client Certificate",
                            placeholder: "None",
                            url: $tlsConfig.clientCertURL,
                            contentTypes: certificateContentTypes)
                        SecurityScopedFilePickerButton(
                            label: "Private Key",
                            placeholder: "None",
                            url: $tlsConfig.clientKeyURL,
                            contentTypes: certificateContentTypes)
                        HStack {
                            Text("SNI Host Override")
                            Spacer()
                            TextField("Optional", text: sniBinding)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 180)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    guard let port else { return }

                    let env = ServerEnvironment(
                        id: existingId ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespaces),
                        host: host.trimmingCharacters(in: .whitespaces),
                        port: port,
                        tlsConfiguration: tlsConfig)
                    onSave(env)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private var sniBinding: Binding<String> {
        Binding(
            get: { tlsConfig.sniOverride ?? "" },
            set: { tlsConfig.sniOverride = $0.isEmpty ? nil : $0 })
    }
}

// MARK: - TLSMode

private enum TLSMode: Hashable {
    case plaintext
    case tls
}

#if DEBUG
    struct EnvironmentPickerView_Previews: PreviewProvider {
        static var previews: some View {
            EnvironmentPickerView(viewModel: PreviewGlobalEnvironmentViewModel())
                .frame(width: 450, height: 400)
        }
    }

    @MainActor
    private final class PreviewGlobalEnvironmentViewModel: GlobalEnvironmentViewModel {
        init() {
            super.init(
                loadEnvironmentsUseCase: PreviewLoadUseCase(),
                saveEnvironmentUseCase: PreviewSaveUseCase(),
                deleteEnvironmentUseCase: PreviewDeleteUseCase(),
                selectEnvironmentUseCase: PreviewSelectUseCase(),
                getSelectedEnvironmentUseCase: PreviewGetSelectedUseCase())
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

    private final class PreviewSaveUseCase: SaveEnvironmentUseCaseProtocol {
        func execute(_: ServerEnvironment) {}
    }

    private final class PreviewDeleteUseCase: DeleteEnvironmentUseCaseProtocol {
        func execute(id _: UUID) {}
    }

    private final class PreviewSelectUseCase: SelectEnvironmentUseCaseProtocol {
        func execute(_: ServerEnvironment?) {}
    }

    private final class PreviewGetSelectedUseCase: GetSelectedEnvironmentUseCaseProtocol {
        func execute() -> ServerEnvironment? {
            nil
        }
    }
#endif
