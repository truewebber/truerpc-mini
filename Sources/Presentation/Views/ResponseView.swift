import SwiftUI

/// View for displaying gRPC response
/// Shows response JSON, timing, status, headers, and trailers
struct ResponseView: View {
    let response: GrpcResponse?
    let error: String?
    let isExecuting: Bool
    let onCopy: () -> Void
    let onExport: () -> Void
    
    @State private var showHeaders: Bool = false
    @State private var showTrailers: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            contentView
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("Response")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if isExecuting {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
                Text("Executing...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let response = response {
                // Action buttons
                HStack(spacing: 8) {
                    // Copy button
                    Button(action: onCopy) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                            Text("Copy")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                    
                    // Export button
                    Button(action: onExport) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.caption2)
                            Text("Export")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                }
                
                // Response time badge
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(formatResponseTime(response.responseTime))
                        .font(.caption)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
                
                // Status badge
                HStack(spacing: 4) {
                    Image(systemName: statusIcon(response.statusCode))
                        .font(.caption2)
                    Text(response.statusMessage)
                        .font(.caption)
                }
                .foregroundColor(statusColor(response.statusCode))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor(response.statusCode).opacity(0.1))
                .cornerRadius(4)
            } else if error != nil {
                // Error indicator
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                    Text("Error")
                        .font(.caption)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isExecuting {
            executingStateView
        } else if let response = response {
            // Show response even if there was an error (for metadata visibility)
            if let error = error {
                errorViewWithMetadata(error, response: response)
            } else {
                responseContentView(response)
            }
        } else if let error = error {
            // Pure error without response
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
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No response yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Click the Play button to execute the request")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func errorView(_ errorMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
                Text("Request Failed")
                    .font(.headline)
                    .foregroundColor(.red)
            }
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.05))
                .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func errorViewWithMetadata(_ errorMessage: String, response: GrpcResponse) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Error message section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        Text("Request Failed")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(8)
                }
                .padding()
                
                // Response body (if present)
                if !response.jsonBody.isEmpty && response.jsonBody != "{}" {
                    Divider()
                    responseBodySection(response)
                }
                
                // Headers section (if present)
                if let headers = response.headers, !headers.isEmpty {
                    Divider()
                    metadataSection(
                        title: "Response Headers",
                        icon: "arrow.down.doc",
                        metadata: headers,
                        isExpanded: $showHeaders
                    )
                }
                
                // Trailers section (if present) - often contains error details
                if let trailers = response.trailers, !trailers.isEmpty {
                    Divider()
                    metadataSection(
                        title: "Response Trailers",
                        icon: "arrow.down.to.line",
                        metadata: trailers,
                        isExpanded: $showTrailers
                    )
                }
                
                // Status details (if present)
                if let statusDetails = response.statusDetails {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status Details")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        Text(statusDetails)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.orange.opacity(0.05))
                    }
                    .padding(.bottom)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func responseContentView(_ response: GrpcResponse) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Response JSON body
                responseBodySection(response)
                
                // Headers section (if present)
                if let headers = response.headers, !headers.isEmpty {
                    Divider()
                    metadataSection(
                        title: "Response Headers",
                        icon: "arrow.down.doc",
                        metadata: headers,
                        isExpanded: $showHeaders
                    )
                }
                
                // Trailers section (if present)
                if let trailers = response.trailers, !trailers.isEmpty {
                    Divider()
                    metadataSection(
                        title: "Response Trailers",
                        icon: "arrow.down.to.line",
                        metadata: trailers,
                        isExpanded: $showTrailers
                    )
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    private func responseBodySection(_ response: GrpcResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response Body")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top)
            
            Text(response.jsonBody)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
    
    private func metadataSection(
        title: String,
        icon: String,
        metadata: [String: String],
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button
            Button(action: {
                withAnimation {
                    isExpanded.wrappedValue.toggle()
                }
            }) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("(\(metadata.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            // Collapsible content
            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top, spacing: 8) {
                            Text(key)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(minWidth: 120, alignment: .leading)
                            
                            Text(value)
                                .font(.system(.caption, design: .monospaced))
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
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatResponseTime(_ time: TimeInterval) -> String {
        if time < 1 {
            return String(format: "%.0f ms", time * 1000)
        } else {
            return String(format: "%.2f s", time)
        }
    }
    
    private func statusColor(_ statusCode: Int) -> Color {
        return statusCode == 0 ? .green : .red
    }
    
    private func statusIcon(_ statusCode: Int) -> String {
        return statusCode == 0 ? "checkmark.circle" : "xmark.circle"
    }
}

// MARK: - Preview

#if DEBUG
struct ResponseView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Empty state
            ResponseView(
                response: nil,
                error: nil,
                isExecuting: false,
                onCopy: {},
                onExport: {}
            )
            .frame(width: 400, height: 300)
            .previewDisplayName("Empty State")
            
            // Executing state
            ResponseView(
                response: nil,
                error: nil,
                isExecuting: true,
                onCopy: {},
                onExport: {}
            )
            .frame(width: 400, height: 300)
            .previewDisplayName("Executing")
            
            // Success response
            ResponseView(
                response: GrpcResponse(
                    jsonBody: """
                    {
                      "id": 123,
                      "name": "Alice Smith",
                      "email": "alice@example.com",
                      "createdAt": "2024-01-15T10:30:00Z"
                    }
                    """,
                    responseTime: 0.156,
                    statusCode: 0,
                    statusMessage: "OK"
                ),
                error: nil,
                isExecuting: false,
                onCopy: { print("Copy tapped") },
                onExport: { print("Export tapped") }
            )
            .frame(width: 400, height: 300)
            .previewDisplayName("Success Response")
            
            // Error state
            ResponseView(
                response: nil,
                error: "Network error: Connection refused. Could not connect to localhost:50051",
                isExecuting: false,
                onCopy: {},
                onExport: {}
            )
            .frame(width: 400, height: 300)
            .previewDisplayName("Error State")
        }
    }
}
#endif
