import SwiftUI

/// View for editing gRPC request parameters
/// Displays URL input, JSON editor, and metadata for a single method
/// 
/// MVP Limitations:
/// - No syntax highlighting (plain TextEditor with monospace)
/// - No JSON validation/formatting
/// - No Play button (Epic 4)
/// - No Response panel (Epic 5)
/// - Mock data is empty JSON "{}" (will use SwiftProtoReflect later)
struct RequestEditorView: View {
    @ObservedObject var viewModel: EditorTabViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with method info
            headerView
            
            Divider()
            
            // URL input
            urlInputView
            
            Divider()
            
            // JSON editor
            jsonEditorView
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
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
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
        
        let viewModel = EditorTabViewModel(
            editorTab: editorTab,
            generateMockDataUseCase: GenerateMockDataUseCase(mockDataGenerator: MockDataGenerator())
        )
        
        viewModel.url = "localhost:50051"
        viewModel.requestJson = "{\n  \"userId\": 1\n}"
        
        return RequestEditorView(viewModel: viewModel)
            .frame(width: 600, height: 400)
            .previewDisplayName("Request Editor")
    }
}
#endif
