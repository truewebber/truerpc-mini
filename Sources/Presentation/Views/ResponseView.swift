import SwiftUI

/// View for displaying gRPC response
/// Shows response JSON, timing, or error state
struct ResponseView: View {
    let response: GrpcResponse?
    let error: String?
    let isExecuting: Bool
    let onCopy: () -> Void
    let onExport: () -> Void
    
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
        } else if let error = error {
            errorView(error)
        } else if let response = response {
            responseContentView(response)
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
    
    private func responseContentView(_ response: GrpcResponse) -> some View {
        VStack(spacing: 0) {
            // Response JSON in read-only editor
            ScrollView {
                Text(response.jsonBody)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
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
