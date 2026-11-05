import SwiftUI

/// Smart lock icon button placed to the left of the URL field.
/// Reflects `ConnectionSecurityViewModel.lockState` and opens the appropriate popover
/// depending on whether a named environment or a custom URL is active.
struct ConnectionSecurityIndicatorView: View {
    @ObservedObject var connectionSecurity: ConnectionSecurityViewModel

    /// Name of the active named environment, or `nil` in custom URL mode.
    let activeEnvironmentName: String?

    /// Called when the user taps "Edit Environment" in the info popover (environment mode only).
    let onEditEnvironment: (() -> Void)?

    /// State for the read-only environment info popover.
    @State private var isInfoPopoverPresented = false

    var body: some View {
        Button {
            if connectionSecurity.isEnvironmentMode {
                isInfoPopoverPresented = true
            } else {
                connectionSecurity.isPopoverPresented = true
            }
        } label: {
            ConnectionLockBadge(state: connectionSecurity.lockState)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .help(ConnectionLockBadge.helpText(for: connectionSecurity.lockState))
        .popover(isPresented: $isInfoPopoverPresented, arrowEdge: .bottom) {
            environmentInfoPopover
        }
        .popover(isPresented: $connectionSecurity.isPopoverPresented, arrowEdge: .bottom) {
            ConnectionSettingsPopoverView(viewModel: connectionSecurity)
        }
    }

    private var environmentInfoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ConnectionLockBadge(state: connectionSecurity.lockState)
                Text("Connection Info")
                    .font(.headline)
            }

            if let name = activeEnvironmentName {
                Text("Using security settings from **\(name)**.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Using security settings from the active environment.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let onEditEnvironment {
                Button("Edit Environment") {
                    isInfoPopoverPresented = false
                    onEditEnvironment()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

#if DEBUG
    #Preview("Plaintext", traits: .fixedLayout(width: 48, height: 32)) {
        ConnectionSecurityIndicatorView(
            connectionSecurity: previewSecurityViewModel(tlsEnabled: false),
            activeEnvironmentName: nil,
            onEditEnvironment: nil)
    }

    #Preview("Secure", traits: .fixedLayout(width: 48, height: 32)) {
        ConnectionSecurityIndicatorView(
            connectionSecurity: previewSecurityViewModel(tlsEnabled: true),
            activeEnvironmentName: nil,
            onEditEnvironment: nil)
    }

    #Preview("Insecure", traits: .fixedLayout(width: 48, height: 32)) {
        ConnectionSecurityIndicatorView(
            connectionSecurity: previewSecurityViewModel(tlsEnabled: true, allowInsecure: true),
            activeEnvironmentName: nil,
            onEditEnvironment: nil)
    }

    #Preview("Environment", traits: .fixedLayout(width: 48, height: 32)) {
        ConnectionSecurityIndicatorView(
            connectionSecurity: previewSecurityViewModel(tlsEnabled: true, environmentName: "Production"),
            activeEnvironmentName: "Production",
            onEditEnvironment: {})
    }

    #Preview("Dark", traits: .fixedLayout(width: 48, height: 32)) {
        ConnectionSecurityIndicatorView(
            connectionSecurity: previewSecurityViewModel(tlsEnabled: true),
            activeEnvironmentName: nil,
            onEditEnvironment: nil)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func previewSecurityViewModel(
        tlsEnabled: Bool,
        allowInsecure: Bool = false,
        environmentName: String? = nil)
        -> ConnectionSecurityViewModel
    {
        let viewModel = ConnectionSecurityViewModel()
        let configuration = TLSConfiguration(isTLSEnabled: tlsEnabled, allowInsecure: allowInsecure)
        if let environmentName {
            let environment = ServerEnvironment(
                name: environmentName,
                host: "localhost",
                port: 50051,
                tlsConfiguration: configuration)
            viewModel.update(activeEnvironment: environment, restoredAdHocConfig: nil)
        } else {
            viewModel.update(activeEnvironment: nil, restoredAdHocConfig: configuration)
        }
        return viewModel
    }
#endif
