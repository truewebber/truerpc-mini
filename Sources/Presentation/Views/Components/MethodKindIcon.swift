import SwiftUI

/// Icon for a unary or streaming RPC.
/// Unary and streaming use different symbols; color only reinforces the symbol.
struct MethodKindIcon: View {
    let isStreaming: Bool

    var body: some View {
        Image(systemName: isStreaming ? "arrow.left.arrow.right" : "arrow.right")
            .foregroundStyle(isStreaming ? AnyShapeStyle(.orange) : AnyShapeStyle(.green))
            .accessibilityLabel(isStreaming ? "Streaming" : "Unary")
    }
}

#if DEBUG
    #Preview("Unary", traits: .sizeThatFitsLayout) {
        MethodKindIcon(isStreaming: false)
            .padding(8)
    }

    #Preview("Streaming", traits: .sizeThatFitsLayout) {
        MethodKindIcon(isStreaming: true)
            .padding(8)
    }

    #Preview("Dark", traits: .sizeThatFitsLayout) {
        MethodKindIcon(isStreaming: true)
            .padding(12)
            .background(.background)
            .preferredColorScheme(.dark)
    }
#endif
