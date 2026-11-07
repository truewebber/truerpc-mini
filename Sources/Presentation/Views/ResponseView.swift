import SwiftUI

/// View for displaying a gRPC response.
/// Shows response JSON, timing, status, headers, and trailers.
struct ResponseView: View {
    let response: GrpcResponse?
    let error: String?
    let isExecuting: Bool
    var isCopied: Bool = false
    let onCopy: () -> Void
    let onExport: () -> Void

    @State private var showHeaders: Bool = false
    @State private var showTrailers: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()
            contentView
        }
    }

    private var headerView: some View {
        HStack {
            Text("Response")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if isExecuting {
                ProgressView()
                    .controlSize(.small)
                Text("Executing...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let response {
                Button(action: onCopy) {
                    Label(isCopied ? "Copied" : "Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Button(action: onExport) {
                    Label("Export", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Label(formatResponseTime(response.responseTime), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GrpcStatusBadge(statusCode: response.statusCode, message: response.statusMessage)
            } else if error != nil {
                Label("Error", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var contentView: some View {
        if isExecuting {
            executingStateView
        } else if let response {
            if let error {
                errorViewWithMetadata(error, response: response)
            } else {
                responseContentView(response)
            }
        } else if let error {
            errorView(error)
        } else {
            emptyStateView
        }
    }

    private var executingStateView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Sending request...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Response Yet", systemImage: "arrow.down.circle")
        } description: {
            Text("Run the request to see the response.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ errorMessage: String) -> some View {
        ContentUnavailableView {
            Label("Request Failed", systemImage: "xmark.circle")
        } description: {
            Text(errorMessage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorViewWithMetadata(_ errorMessage: String, response: GrpcResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Request Failed", systemImage: "xmark.circle")
                        .font(.headline)
                        .foregroundStyle(.red)

                    Text(errorMessage)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()

                if !response.jsonBody.isEmpty, response.jsonBody != "{}" {
                    Divider()
                    responseBodySection(response)
                }

                if let headers = response.headers, !headers.isEmpty {
                    Divider()
                    metadataSection(
                        title: "Response Headers",
                        icon: "arrow.down.doc",
                        metadata: headers,
                        isExpanded: $showHeaders)
                }

                if let trailers = response.trailers, !trailers.isEmpty {
                    Divider()
                    metadataSection(
                        title: "Response Trailers",
                        icon: "arrow.down.to.line",
                        metadata: trailers,
                        isExpanded: $showTrailers)
                }

                if let statusDetails = response.statusDetails {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status Details")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(statusDetails)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
            }
        }
    }

    private func responseContentView(_ response: GrpcResponse) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                responseBodySection(response)

                if let headers = response.headers, !headers.isEmpty {
                    Divider()
                    metadataSection(
                        title: "Response Headers",
                        icon: "arrow.down.doc",
                        metadata: headers,
                        isExpanded: $showHeaders)
                }

                if let trailers = response.trailers, !trailers.isEmpty {
                    Divider()
                    metadataSection(
                        title: "Response Trailers",
                        icon: "arrow.down.to.line",
                        metadata: trailers,
                        isExpanded: $showTrailers)
                }
            }
        }
    }

    private func responseBodySection(_ response: GrpcResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response Body")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(JsonSyntaxHighlighter().attributedText(JsonInlineDocument.expanded(response.jsonBody)))
                .font(JsonEditorMetrics.swiftUIFont)
                .lineSpacing(JsonEditorMetrics.lineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    private func metadataSection(
        title: String,
        icon: String,
        metadata: [String: String],
        isExpanded: Binding<Bool>)
        -> some View
    {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("(\(metadata.count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top, spacing: 8) {
                            Text(key)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 120, alignment: .leading)

                            Text(value)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)

                        if key != metadata.sorted(by: { $0.key < $1.key }).last?.key {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func formatResponseTime(_ time: TimeInterval) -> String {
        if time < 1 {
            String(format: "%.0f ms", time * 1000)
        } else {
            String(format: "%.2f s", time)
        }
    }
}

#if DEBUG
    #Preview("Empty", traits: .fixedLayout(width: 390, height: 594)) {
        ResponseView(
            response: nil,
            error: nil,
            isExecuting: false,
            onCopy: {},
            onExport: {})
    }

    #Preview("Executing", traits: .fixedLayout(width: 390, height: 594)) {
        ResponseView(
            response: nil,
            error: nil,
            isExecuting: true,
            onCopy: {},
            onExport: {})
    }

    #Preview("Success", traits: .fixedLayout(width: 390, height: 594)) {
        ResponseView(
            response: .previewSuccess,
            error: nil,
            isExecuting: false,
            onCopy: {},
            onExport: {})
    }

    #Preview("Error", traits: .fixedLayout(width: 390, height: 594)) {
        ResponseView(
            response: nil,
            error: "Network error: Connection refused. Could not connect to localhost:50051",
            isExecuting: false,
            onCopy: {},
            onExport: {})
    }

    #Preview("Error With Response", traits: .fixedLayout(width: 390, height: 594)) {
        ResponseView(
            response: .previewFailure,
            error: "gRPC error: permission denied for UserService.GetUser",
            isExecuting: false,
            onCopy: {},
            onExport: {})
    }

    #Preview("Long Content", traits: .fixedLayout(width: 390, height: 594)) {
        ResponseView(
            response: .previewLong,
            error: nil,
            isExecuting: false,
            onCopy: {},
            onExport: {})
    }

    #Preview("Dark", traits: .fixedLayout(width: 390, height: 594)) {
        ResponseView(
            response: .previewSuccess,
            error: nil,
            isExecuting: false,
            onCopy: {},
            onExport: {})
            .preferredColorScheme(.dark)
    }
#endif
