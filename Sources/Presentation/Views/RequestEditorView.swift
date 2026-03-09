import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// View for editing gRPC request parameters and displaying responses
/// Displays URL input, JSON editor, Play button, and response panel
struct RequestEditorView: View {
    @ObservedObject var viewModel: EditorTabViewModel
    @ObservedObject var globalEnvironmentViewModel: GlobalEnvironmentViewModel
    @State private var showExportError: Bool = false
    @State private var exportErrorMessage: String = ""
    @State private var showCopySuccess: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with method info and Play button
            headerView

            Divider()

            // Split view: Request Editor (left) | Response (right)
            HSplitView {
                // Left: Request editor — min 280 so it never vanishes but window min enforces real minimum
                requestEditorView
                    .frame(minWidth: 280)

                // Right: Response panel
                ResponseView(
                    response: viewModel.response,
                    error: viewModel.error,
                    isExecuting: viewModel.isExecuting,
                    onCopy: {
                        viewModel.copyResponse()
                        withAnimation {
                            showCopySuccess = true
                        }
                    },
                    onExport: {
                        Task {
                            await exportResponse()
                        }
                    })
                    .frame(minWidth: 280)
            }
        }
        .task {
            // Load mock data when view appears
            await viewModel.loadMockData()
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
        .overlay(alignment: .top) {
            if showCopySuccess {
                Text("Copied to clipboard")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showCopySuccess = false
                            }
                        }
                    }
            }
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

            // Metadata toggle button
            Button(action: {
                withAnimation {
                    viewModel.toggleMetadataVisibility()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet.rectangle")
                    Text("Metadata")
                }
            }
            .buttonStyle(.bordered)
            .help("Toggle metadata headers editor")

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
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var requestEditorView: some View {
        VSplitView {
            // Top: URL and JSON editor
            VStack(spacing: 0) {
                // URL input
                urlInputView

                Divider()

                // JSON editor
                jsonEditorView
            }
            .frame(minHeight: 200)

            // Bottom: Metadata panel (collapsible)
            if viewModel.isMetadataVisible {
                metadataEditorView
                    .frame(minHeight: 100, idealHeight: 150)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var urlInputView: some View {
        HStack(spacing: 8) {
            if !globalEnvironmentViewModel.environments.isEmpty {
                envPicker
            } else {
                Text("URL")
                    .font(.subheadline)
                    .frame(width: 60, alignment: .leading)
            }

            TextField("localhost:50051", text: Binding(
                get: { viewModel.url },
                set: { viewModel.updateUrl($0) }))
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.tabEnvironment != nil)
        }
        .padding()
    }

    private var envPicker: some View {
        Menu {
            ForEach(globalEnvironmentViewModel.environments) { env in
                Button {
                    viewModel.selectTabEnvironment(env)
                } label: {
                    Label {
                        Text("\(env.name) — \(env.url)")
                    } icon: {
                        if viewModel.tabEnvironment?.id == env.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button("Custom URL") {
                viewModel.useCustomUrl(viewModel.url)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.caption)
                Text(viewModel.tabEnvironment?.name ?? "Custom")
                    .font(.subheadline)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var jsonEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Request Body")
                .font(.subheadline)
                .foregroundColor(.secondary)

            JSONTextEditor(text: Binding(
                get: { viewModel.requestJson },
                set: { viewModel.updateJson($0) }))
                .id("json-editor-\(viewModel.editorTab.id)")
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(Color.secondary.opacity(0.2), width: 1)
        }
        .padding()
    }

    private var metadataEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Metadata (Headers)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("JSON format: {\"key\": \"value\"}")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            JSONTextEditor(text: Binding(
                get: { viewModel.metadataJson },
                set: { viewModel.updateMetadata($0) }))
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(Color.secondary.opacity(0.2), width: 1)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Actions

    @MainActor
    private func exportResponse() async {
        guard let window = NSApp.keyWindow else {
            exportErrorMessage = "Unable to show save dialog"
            showExportError = true
            return
        }

        // Create save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = viewModel.exportResponseUseCase.generateDefaultFilename()
        savePanel.canCreateDirectories = true
        savePanel.title = "Export Response"
        savePanel.message = "Choose where to save the response"

        // Use continuation to bridge callback-based API to async/await
        let url: URL? = await withCheckedContinuation { continuation in
            savePanel.beginSheetModal(for: window) { response in
                if response == .OK {
                    continuation.resume(returning: savePanel.url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }

        guard let url else {
            return
        }

        do {
            try viewModel.exportResponse(to: url)
        } catch {
            exportErrorMessage = "Failed to export response: \(error.localizedDescription)"
            showExportError = true
        }
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
                isStreaming: false)
            let service = Service(name: "UserService", methods: [method])
            let protoFile = ProtoFile(
                name: "users.proto",
                path: URL(fileURLWithPath: "/test/users.proto"),
                services: [service])
            let editorTab = EditorTab(
                methodName: method.name,
                serviceName: service.name,
                protoFile: protoFile,
                method: method)

            // Create mock use cases for preview
            let mockExecuteUseCase = PreviewMockExecuteUseCase()
            let mockFileManager = PreviewMockFileManager()
            let exportUseCase = ExportResponseUseCase(fileManager: mockFileManager)

            let viewModel = EditorTabViewModel(
                editorTab: editorTab,
                generateMockDataUseCase: GenerateMockDataUseCase(mockDataGenerator: MockDataGenerator()),
                executeRequestUseCase: mockExecuteUseCase,
                exportResponseUseCase: exportUseCase,
                logger: NullLogger())

            viewModel.url = "localhost:50051"
            viewModel.requestJson = "{\n  \"userId\": 1\n}"

            return RequestEditorView(
                viewModel: viewModel,
                globalEnvironmentViewModel: RequestEditorView_PreviewEnvViewModel())
                .frame(width: 600, height: 400)
                .previewDisplayName("Request Editor")
        }
    }

    // MARK: - Preview Mocks

    @MainActor
    private final class RequestEditorView_PreviewEnvViewModel: GlobalEnvironmentViewModel {
        init() {
            super.init(
                loadEnvironmentsUseCase: RequestEditorView_PreviewLoadEnvs(),
                saveEnvironmentUseCase: RequestEditorView_PreviewNoOpSave(),
                deleteEnvironmentUseCase: RequestEditorView_PreviewNoOpDelete(),
                selectEnvironmentUseCase: RequestEditorView_PreviewNoOpSelect(),
                getSelectedEnvironmentUseCase: RequestEditorView_PreviewNoOpGetSelected())
        }
    }

    private final class RequestEditorView_PreviewLoadEnvs: LoadEnvironmentsUseCaseProtocol {
        func execute() -> [ServerEnvironment] {
            [ServerEnvironment(name: "Local", host: "localhost", port: 50051)]
        }
    }

    private final class RequestEditorView_PreviewNoOpSave: SaveEnvironmentUseCaseProtocol {
        func execute(_: ServerEnvironment) {}
    }

    private final class RequestEditorView_PreviewNoOpDelete: DeleteEnvironmentUseCaseProtocol {
        func execute(id _: UUID) {}
    }

    private final class RequestEditorView_PreviewNoOpSelect: SelectEnvironmentUseCaseProtocol {
        func execute(_: ServerEnvironment?) {}
    }

    private final class RequestEditorView_PreviewNoOpGetSelected: GetSelectedEnvironmentUseCaseProtocol {
        func execute() -> ServerEnvironment? {
            nil
        }
    }

    private class PreviewMockExecuteUseCase: ExecuteUnaryRequestUseCaseProtocol {
        func execute(request _: RequestDraft, method _: TrueRPCMini.Method) throws -> GrpcResponse {
            // Return mock response for preview
            GrpcResponse(
                jsonBody: #"{"id": 1, "name": "Preview User"}"#,
                responseTime: 0.123,
                statusCode: 0,
                statusMessage: "OK")
        }
    }

    private class PreviewMockFileManager: FileManagerProtocol {
        func write(_: Data, to _: URL) throws {
            // No-op for preview
        }
    }
#endif

// MARK: - JSON Text Editor

/// Custom text editor for JSON with smart quotes disabled
struct JSONTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        // Disable smart quotes and dashes
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Set monospaced font
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        // Enable wrapping
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        textView.delegate = context.coordinator
        textView.string = text

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context _: Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JSONTextEditor

        init(_ parent: JSONTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            parent.text = textView.string
        }
    }
}
