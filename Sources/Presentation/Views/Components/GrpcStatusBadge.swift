import SwiftUI

/// gRPC status as a symbol plus text, without a filled background.
struct GrpcStatusBadge: View {
    let statusCode: Int
    let message: String

    private var isSuccess: Bool {
        statusCode == 0
    }

    var body: some View {
        Label {
            Text(message)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: isSuccess ? "checkmark.circle" : "xmark.circle")
        }
        .font(.caption)
        .foregroundStyle(isSuccess ? AnyShapeStyle(.green) : AnyShapeStyle(.red))
        .help(message)
    }
}

#if DEBUG
    #Preview("OK", traits: .sizeThatFitsLayout) {
        GrpcStatusBadge(statusCode: 0, message: "OK")
            .padding(8)
    }

    #Preview("Failed", traits: .sizeThatFitsLayout) {
        GrpcStatusBadge(statusCode: 7, message: "PERMISSION_DENIED")
            .padding(8)
    }

    #Preview("Long Message", traits: .sizeThatFitsLayout) {
        GrpcStatusBadge(
            statusCode: 3,
            message: "INVALID_ARGUMENT: user.address.postalCode is not a valid postal code for the selected country")
            .padding(8)
    }

    #Preview("Dark", traits: .sizeThatFitsLayout) {
        GrpcStatusBadge(statusCode: 7, message: "PERMISSION_DENIED")
            .padding(12)
            .background(.background)
            .preferredColorScheme(.dark)
    }
#endif
