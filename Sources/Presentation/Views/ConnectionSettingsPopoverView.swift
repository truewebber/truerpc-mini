import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// TLS configuration form shown in a popover when the user clicks the lock icon
/// in custom URL mode. Binds directly to `ConnectionSecurityViewModel.adHocConfig`.
public struct ConnectionSettingsPopoverView: View {
    @ObservedObject var viewModel: ConnectionSecurityViewModel

    public init(viewModel: ConnectionSecurityViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text("Connection Security")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            Divider()

            Form {
                Section("Security") {
                    Picker("Mode", selection: $viewModel.adHocConfig.isTLSEnabled) {
                        Text("Plaintext").tag(false)
                        Text("TLS").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                if viewModel.adHocConfig.isTLSEnabled {
                    Section("Server Authentication") {
                        Toggle("Allow Insecure (Skip Verify)", isOn: $viewModel.adHocConfig.allowInsecure)
                        SecurityScopedFilePickerButton(
                            label: "Custom CA Certificate",
                            placeholder: "None",
                            url: $viewModel.adHocConfig.customCAURL,
                            contentTypes: certificateContentTypes)
                    }

                    Section("Client Authentication (mTLS)") {
                        SecurityScopedFilePickerButton(
                            label: "Client Certificate",
                            placeholder: "None",
                            url: $viewModel.adHocConfig.clientCertURL,
                            contentTypes: certificateContentTypes)
                        SecurityScopedFilePickerButton(
                            label: "Private Key",
                            placeholder: "None",
                            url: $viewModel.adHocConfig.clientKeyURL,
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
            .frame(height: viewModel.adHocConfig.isTLSEnabled ? 400 : 92)
            .animation(.easeInOut(duration: 0.2), value: viewModel.adHocConfig.isTLSEnabled)
        }
        .frame(width: 360)
    }

    // MARK: - Helpers

    private var sniBinding: Binding<String> {
        Binding(
            get: { viewModel.adHocConfig.sniOverride ?? "" },
            set: { viewModel.adHocConfig.sniOverride = $0.isEmpty ? nil : $0 })
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
}

// MARK: - SecurityScopedFilePickerButton

/// A button that shows the selected file's name and opens a file picker on tap.
/// Uses SwiftUI's `.fileImporter` which handles security-scoped resources automatically.
struct SecurityScopedFilePickerButton: View {
    let label: String
    let placeholder: String
    @Binding var url: URL?
    let contentTypes: [UTType]

    @State private var isPickerPresented = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Button {
                isPickerPresented = true
            } label: {
                Text(url?.lastPathComponent ?? placeholder)
                    .foregroundColor(url == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160, alignment: .trailing)
            }
            .buttonStyle(.borderless)

            if url != nil {
                Button {
                    url = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: contentTypes,
            allowsMultipleSelection: false)
        { result in
            if case let .success(urls) = result {
                url = urls.first
            }
        }
    }
}

#if DEBUG
    struct ConnectionSettingsPopoverView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                ConnectionSettingsPopoverView(viewModel: previewViewModel(tlsEnabled: false))
                    .previewDisplayName("Plaintext")

                ConnectionSettingsPopoverView(viewModel: previewViewModel(tlsEnabled: true))
                    .previewDisplayName("TLS Enabled")
            }
        }

        @MainActor
        private static func previewViewModel(tlsEnabled: Bool) -> ConnectionSecurityViewModel {
            let vm = ConnectionSecurityViewModel()
            vm.update(
                activeEnvironment: nil,
                restoredAdHocConfig: TLSConfiguration(isTLSEnabled: tlsEnabled))
            return vm
        }
    }
#endif
