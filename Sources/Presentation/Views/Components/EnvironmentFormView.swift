import SwiftUI
import UniformTypeIdentifiers

/// Sheet for creating or editing a ServerEnvironment.
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
                }

                if tlsConfig.isTLSEnabled {
                    Section("Server Authentication") {
                        Toggle("Allow Insecure (Skip Verify)", isOn: $tlsConfig.allowInsecure)
                        SecurityScopedFilePickerButton(
                            label: "Custom CA Certificate",
                            placeholder: "None",
                            url: $tlsConfig.customCAURL,
                            contentTypes: certificateContentTypes)
                    }

                    Section("Client Authentication (mTLS)") {
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
                    }

                    Section("Advanced") {
                        HStack {
                            Text("SNI Host Override")
                            Spacer()
                            TextField("Optional", text: sniBinding)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)
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

private enum TLSMode: Hashable {
    case plaintext
    case tls
}

#if DEBUG
    #Preview("Create", traits: .fixedLayout(width: 460, height: 480)) {
        EnvironmentFormView(
            onSave: { _ in },
            onCancel: {})
    }

    #Preview("Edit", traits: .fixedLayout(width: 460, height: 740)) {
        EnvironmentFormView(
            environment: .previewStaging,
            onSave: { _ in },
            onCancel: {})
    }

    #Preview("Invalid", traits: .fixedLayout(width: 460, height: 480)) {
        EnvironmentFormView(
            environment: ServerEnvironment(name: "", host: "localhost", port: 50051),
            onSave: { _ in },
            onCancel: {})
    }

    #Preview("Dark", traits: .fixedLayout(width: 460, height: 740)) {
        EnvironmentFormView(
            environment: .previewStaging,
            onSave: { _ in },
            onCancel: {})
            .preferredColorScheme(.dark)
    }
#endif
