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
            Image(systemName: lockSymbol)
                .foregroundColor(lockColor)
                .font(.system(size: 16))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .help(lockHelp)
        .popover(isPresented: $isInfoPopoverPresented) {
            environmentInfoPopover
        }
        .popover(isPresented: $connectionSecurity.isPopoverPresented) {
            ConnectionSettingsPopoverView(viewModel: connectionSecurity)
        }
    }

    // MARK: - Lock Appearance

    private var lockSymbol: String {
        switch connectionSecurity.lockState {
        case .plaintext:
            "lock.open"
        case .secure:
            "lock.fill"
        case .insecure:
            "lock.trianglebadge.exclamationmark.fill"
        }
    }

    private var lockColor: Color {
        switch connectionSecurity.lockState {
        case .plaintext:
            .secondary
        case .secure:
            .green
        case .insecure:
            .yellow
        }
    }

    private var lockHelp: String {
        switch connectionSecurity.lockState {
        case .plaintext:
            "Plaintext connection — no TLS"
        case .secure:
            "Secure TLS connection"
        case .insecure:
            "TLS enabled with relaxed verification"
        }
    }

    // MARK: - Environment Info Popover

    private var environmentInfoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: lockSymbol)
                    .foregroundColor(lockColor)
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
    struct ConnectionSecurityIndicatorView_Previews: PreviewProvider {
        static var previews: some View {
            Group {
                ConnectionSecurityIndicatorView(
                    connectionSecurity: makeVM(tlsEnabled: false, envName: nil),
                    activeEnvironmentName: nil,
                    onEditEnvironment: nil)
                    .previewDisplayName("Plaintext")

                ConnectionSecurityIndicatorView(
                    connectionSecurity: makeVM(tlsEnabled: true, envName: nil),
                    activeEnvironmentName: nil,
                    onEditEnvironment: nil)
                    .previewDisplayName("Secure")

                ConnectionSecurityIndicatorView(
                    connectionSecurity: makeVM(tlsEnabled: true, envName: "Production"),
                    activeEnvironmentName: "Production",
                    onEditEnvironment: {})
                    .previewDisplayName("Environment Mode")
            }
            .padding()
        }

        @MainActor
        private static func makeVM(tlsEnabled: Bool, envName: String?) -> ConnectionSecurityViewModel {
            let vm = ConnectionSecurityViewModel()
            let env = envName.map { ServerEnvironment(
                name: $0,
                host: "localhost",
                port: 50051,
                tlsConfiguration: TLSConfiguration(isTLSEnabled: tlsEnabled))
            }
            vm.update(activeEnvironment: env, restoredAdHocConfig: nil)
            return vm
        }
    }
#endif
