import SwiftUI

/// Lock glyph for a connection security state.
/// Chooses the symbol, semantic color, and help text for plaintext, secure, and insecure TLS.
struct ConnectionLockBadge: View {
    let state: LockIndicatorState

    var body: some View {
        Image(systemName: Self.symbol(for: state))
            .font(.body)
            .foregroundStyle(Self.tint(for: state))
            .help(Self.helpText(for: state))
            .accessibilityLabel(Self.helpText(for: state))
    }

    static func helpText(for state: LockIndicatorState) -> String {
        switch state {
        case .plaintext:
            "Plaintext connection — no TLS"
        case .secure:
            "Secure TLS connection"
        case .insecure:
            "TLS enabled with relaxed verification"
        }
    }

    private static func symbol(for state: LockIndicatorState) -> String {
        switch state {
        case .plaintext:
            "lock.open"
        case .secure:
            "lock.fill"
        case .insecure:
            "lock.trianglebadge.exclamationmark.fill"
        }
    }

    private static func tint(for state: LockIndicatorState) -> Color {
        switch state {
        case .plaintext:
            .secondary
        case .secure:
            .green
        case .insecure:
            .yellow
        }
    }
}

#if DEBUG
    #Preview("Plaintext", traits: .sizeThatFitsLayout) {
        ConnectionLockBadge(state: .plaintext)
            .padding(8)
    }

    #Preview("Secure", traits: .sizeThatFitsLayout) {
        ConnectionLockBadge(state: .secure)
            .padding(8)
    }

    #Preview("Insecure", traits: .sizeThatFitsLayout) {
        ConnectionLockBadge(state: .insecure)
            .padding(8)
    }

    #Preview("Dark", traits: .sizeThatFitsLayout) {
        ConnectionLockBadge(state: .secure)
            .padding(12)
            .background(.background)
            .preferredColorScheme(.dark)
    }
#endif
