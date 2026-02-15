import SwiftUI

/// View for editing gRPC request parameters and displaying responses
/// Displays URL input, JSON editor, Play button, and response panel
struct RequestEditorView: View {
    @ObservedObject var viewModel: EditorTabViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with method info and Play button
            headerView
            
            Divider()
            
            // Split view: Request Editor (left) | Response (right)
            HSplitView {
                // Left: Request editor
                requestEditorView
                    .frame(minWidth: 300)
                
                // Right: Response panel
                ResponseView(
                    response: viewModel.response,
                    error: viewModel.error,
                    isExecuting: viewModel.isExecuting
                )
                .frame(minWidth: 300)
            }
        }
        .task {
            // Load mock data when view appears
            await viewModel.loadMockData()
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.editorTab.methodName)
                    .font(.headline)
                Text("\(viewModel.editorTab.serviceName) • \(viewModel.editorTab.protoFile.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Play button
            Button(action: {
                Task {
                    await viewModel.executeRequest()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isExecuting ? "stop.fill" : "play.fill")
                    Text(viewModel.isExecuting ? "Executing" : "Execute")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isExecuting || viewModel.url.isEmpty || viewModel.requestJson.isEmpty)
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var requestEditorView: some View {
        VStack(spacing: 0) {
            // URL input
            urlInputView
            
            Divider()
            
            // JSON editor
            jsonEditorView
        }
    }
    
    private var urlInputView: some View {
        HStack {
            Text("URL")
                .font(.subheadline)
                .frame(width: 60, alignment: .leading)
            
            TextField("localhost:50051", text: Binding(
                get: { viewModel.url },
                set: { viewModel.updateUrl($0) }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .padding()
    }
    
    private var jsonEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Request Body")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextEditor(text: Binding(
                get: { viewModel.requestJson },
                set: { viewModel.updateJson($0) }
            ))
            .font(.system(.body, design: .monospaced))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .border(Color.secondary.opacity(0.2), width: 1)
        }
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct RequestEditorView_Previews: PreviewProvider {
    static var previews: some View {
        let method = TrueRPCMini.Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false
        )
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [service]
        )
        let editorTab = EditorTab(
            methodName: method.name,
            serviceName: service.name,
            protoFile: protoFile,
            method: method
        )
        
        // Create mock use case for preview
        let mockExecuteUseCase = PreviewMockExecuteUseCase()
        
        let viewModel = EditorTabViewModel(
            editorTab: editorTab,
            generateMockDataUseCase: GenerateMockDataUseCase(mockDataGenerator: MockDataGenerator()),
            executeRequestUseCase: mockExecuteUseCase
        )
        
        viewModel.url = "localhost:50051"
        viewModel.requestJson = "{\n  \"userId\": 1\n}"
        
        return RequestEditorView(viewModel: viewModel)
            .frame(width: 600, height: 400)
            .previewDisplayName("Request Editor")
    }
}

// MARK: - Preview Mock

private class PreviewMockExecuteUseCase: ExecuteUnaryRequestUseCaseProtocol {
    func execute(request: RequestDraft, method: TrueRPCMini.Method) async throws -> GrpcResponse {
        // Return mock response for preview
        return GrpcResponse(
            jsonBody: #"{"id": 1, "name": "Preview User"}"#,
            responseTime: 0.123,
            statusCode: 0,
            statusMessage: "OK"
        )
    }
}
#endif
