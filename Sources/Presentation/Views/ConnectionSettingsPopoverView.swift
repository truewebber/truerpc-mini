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

#if DEBUG
    #Preview("Plaintext", traits: .fixedLayout(width: 360, height: 180)) {
        ConnectionSettingsPopoverView(viewModel: previewConnectionSettingsViewModel(tlsEnabled: false))
    }

    #Preview("TLS", traits: .fixedLayout(width: 360, height: 520)) {
        ConnectionSettingsPopoverView(viewModel: previewConnectionSettingsViewModel(tlsEnabled: true))
    }

    #Preview("Long Content", traits: .fixedLayout(width: 360, height: 520)) {
        ConnectionSettingsPopoverView(viewModel: previewConnectionSettingsViewModel(
            tlsEnabled: true,
            sniOverride: "edge.payments.customer-facing.eu-west-1.internal.example.com",
            customCAURL: URL(
                fileURLWithPath: "/Users/shared/certs/production/west-europe/customer-facing/intermediates/internal-corporate-root-certificate-authority.pem")))
    }

    #Preview("Dark", traits: .fixedLayout(width: 360, height: 520)) {
        ConnectionSettingsPopoverView(viewModel: previewConnectionSettingsViewModel(tlsEnabled: true))
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func previewConnectionSettingsViewModel(
        tlsEnabled: Bool,
        sniOverride: String? = nil,
        customCAURL: URL? = nil)
        -> ConnectionSecurityViewModel
    {
        let viewModel = ConnectionSecurityViewModel()
        viewModel.update(
            activeEnvironment: nil,
            restoredAdHocConfig: TLSConfiguration(
                isTLSEnabled: tlsEnabled,
                customCAURL: customCAURL,
                sniOverride: sniOverride))
        return viewModel
    }
#endif
