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
    @State private var editingEnvironment: ServerEnvironment?

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
        .sheet(item: $editingEnvironment) { env in
            EnvironmentFormView(environment: env, onSave: { updated in
                globalEnvironmentViewModel.saveEnvironment(updated)
                viewModel.selectTabEnvironment(updated)
                editingEnvironment = nil
            }, onCancel: {
                editingEnvironment = nil
            })
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
            ConnectionSecurityIndicatorView(
                connectionSecurity: viewModel.connectionSecurity,
                activeEnvironmentName: viewModel.tabEnvironment?.name,
                onEditEnvironment: viewModel.tabEnvironment != nil
                    ? { editingEnvironment = viewModel.tabEnvironment }
                    : nil)

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
            HStack {
                Text("Request Body")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    Task { await viewModel.resetToPreset() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.isLoading)
                .help("Reset to Preset")
            }

            JSONTextEditor(
                text: Binding(
                    get: { viewModel.requestJson },
                    set: { viewModel.updateJson($0) }),
                autocompleteViewModel: viewModel.autocompleteViewModel,
                protoFile: viewModel.editorTab.protoFile)
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
                generateMockDataUseCase: GenerateMockDataUseCase(
                    mockDataGenerator: RequestEditorView_PreviewStubMockDataGenerator()),
                executeRequestUseCase: mockExecuteUseCase,
                exportResponseUseCase: exportUseCase,
                autocompleteProvider: RequestEditorView_PreviewStubAutocompleteProvider(),
                resolver: JsonPathResolver(),
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

    private struct RequestEditorView_PreviewStubMockDataGenerator: MockDataGeneratorProtocol {
        func generate(for _: String, in _: ProtoFile) throws -> String {
            "{}"
        }
    }

    private struct RequestEditorView_PreviewStubAutocompleteProvider: AutocompleteProviderProtocol {
        func suggestions(for _: AutocompleteContext, in _: ProtoFile) -> [AutocompleteSuggestion] {
            []
        }
    }

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

    private final class PreviewMockExecuteUseCase: ExecuteUnaryRequestUseCaseProtocol {
        func execute(request _: RequestDraft, method _: TrueRPCMini.Method, protoFile _: ProtoFile) throws
            -> GrpcResponse
        {
            // Return mock response for preview
            GrpcResponse(
                jsonBody: #"{"id": 1, "name": "Preview User"}"#,
                responseTime: 0.123,
                statusCode: 0,
                statusMessage: "OK")
        }
    }

    private final class PreviewMockFileManager: FileManagerProtocol {
        func write(_: Data, to _: URL) throws {
            // No-op for preview
        }
    }
#endif

// MARK: - JSON Text Editor

/// Custom text editor for JSON with smart quotes disabled.
/// When `autocompleteViewModel` and `protoFile` are provided the editor hooks
/// into the autocomplete pipeline: it calls the view-model on every keystroke
/// and hosts an `NSPopover` (anchored at the text cursor) that shows suggestions.
struct JSONTextEditor: NSViewRepresentable {
    @Binding var text: String
    var autocompleteViewModel: AutocompleteViewModel?
    var protoFile: ProtoFile?

    init(
        text: Binding<String>,
        autocompleteViewModel: AutocompleteViewModel? = nil,
        protoFile: ProtoFile? = nil)
    {
        _text = text
        self.autocompleteViewModel = autocompleteViewModel
        self.protoFile = protoFile
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

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

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JSONTextEditor

        init(_ parent: JSONTextEditor) {
            self.parent = parent
        }

        /// Single NSPopover instance owned by this coordinator.
        /// .applicationDefined prevents AppKit from auto-closing it on the next keystroke.
        lazy var autocompletePopover: NSPopover = {
            let popover = NSPopover()
            popover.behavior = .applicationDefined
            popover.animates = false
            if let vm = parent.autocompleteViewModel {
                popover.contentViewController = NSHostingController(
                    rootView: AutocompletePopoverView(viewModel: vm))
            }
            return popover
        }()

        // MARK: NSTextViewDelegate — text changes

        nonisolated func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            MainActor.assumeIsolated {
                let text = textView.string
                let cursorOffset = textView.selectedRange().location
                parent.text = text

                guard let vm = parent.autocompleteViewModel,
                      let protoFile = parent.protoFile
                else { return }

                Task { @MainActor [weak textView] in
                    await vm.textDidChange(text, cursorOffset: cursorOffset, protoFile: protoFile)
                    guard let textView else { return }

                    if vm.isVisible {
                        self.showPopoverIfNeeded(in: textView)
                    } else {
                        self.autocompletePopover.close()
                    }
                }
            }
        }

        // MARK: NSTextViewDelegate — keyboard commands

        nonisolated func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector)
            -> Bool
        {
            MainActor.assumeIsolated {
                guard let vm = parent.autocompleteViewModel, vm.isVisible else { return false }

                switch commandSelector {
                case #selector(NSTextView.moveUp(_:)):
                    vm.moveUp()
                    return true

                case #selector(NSTextView.moveDown(_:)):
                    vm.moveDown()
                    return true

                case #selector(NSTextView.insertNewline(_:)),
                     #selector(NSTextView.insertTab(_:)):
                    guard let suggestion = vm.commitSelection() else { return false }

                    applySmartInsert(suggestion: suggestion, to: textView)

                    if suggestion.kind == .message, let protoFile = parent.protoFile {
                        let newText = textView.string
                        let offset = textView.selectedRange().location
                        Task { @MainActor [weak textView] in
                            await vm.textDidChange(newText, cursorOffset: offset, protoFile: protoFile)
                            guard let textView else { return }

                            if vm.isVisible { self.showPopoverIfNeeded(in: textView) }
                        }
                    } else {
                        vm.dismiss()
                        autocompletePopover.close()
                    }
                    return true

                case #selector(NSResponder.cancelOperation(_:)):
                    vm.dismiss()
                    autocompletePopover.close()
                    return true

                default:
                    return false
                }
            }
        }

        // MARK: - Popover positioning

        private func showPopoverIfNeeded(in textView: NSTextView) {
            guard let window = textView.window else { return }

            let range = textView.selectedRange()
            let rect = cursorViewRect(in: textView, range: range, window: window)
            if !autocompletePopover.isShown {
                autocompletePopover.show(relativeTo: rect, of: textView, preferredEdge: .maxY)
            }
        }

        private func cursorViewRect(
            in textView: NSTextView,
            range: NSRange,
            window: NSWindow)
            -> NSRect
        {
            // Screen coords → window space → textView local space
            let screenRect = textView.firstRect(forCharacterRange: range, actualRange: nil)
            let windowRect = window.convertFromScreen(screenRect)
            return textView.convert(windowRect, from: nil)
        }

        // MARK: - Smart insert

        private func applySmartInsert(suggestion: AutocompleteSuggestion, to textView: NSTextView) {
            let (insertText, cursorBack) = Self.smartInsertComponents(for: suggestion)
            guard !insertText.isEmpty else { return }

            let range = textView.selectedRange()
            if textView.shouldChangeText(in: range, replacementString: insertText) {
                textView.replaceCharacters(in: range, with: insertText)
                textView.didChangeText()
                parent.text = textView.string

                if cursorBack > 0 {
                    let newPos = range.location + insertText.utf16.count - cursorBack
                    textView.setSelectedRange(NSRange(location: max(0, newPos), length: 0))
                }
            }
        }

        /// Returns the snippet text and the number of UTF-16 code units to step
        /// the cursor back after insertion (for placing the cursor inside quotes/braces).
        static func smartInsertComponents(
            for suggestion: AutocompleteSuggestion)
            -> (text: String, cursorBack: Int)
        {
            let name = suggestion.name
            switch suggestion.kind {
            case .string:
                return ("\"\(name)\": \"\"", 1)
            case .number, .bool:
                return ("\"\(name)\": ", 0)
            case .message:
                return ("\"\(name)\": {\n  \n}", 2)
            case .enum:
                return ("\"\(name)\"", 0)
            case .repeated:
                return ("\"\(name)\": []", 1)
            case .fillDefaults:
                return ("", 0)
            }
        }
    }
}
