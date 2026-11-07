import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// View for editing gRPC request parameters and displaying responses.
/// Displays URL input, JSON editor, Play button, and response panel.
struct RequestEditorView: View {
    @ObservedObject var viewModel: EditorTabViewModel
    @ObservedObject var globalEnvironmentViewModel: GlobalEnvironmentViewModel
    @Environment(\.hotkeys) private var hotkeys
    @State private var showExportError: Bool
    @State private var exportErrorMessage: String
    @State private var isResponseCopied: Bool
    @State private var editingEnvironment: ServerEnvironment?
    @State private var copyConfirmationTask: Task<Void, Never>?
    private let loadsMockDataOnAppear: Bool

    init(
        viewModel: EditorTabViewModel,
        globalEnvironmentViewModel: GlobalEnvironmentViewModel,
        isResponseCopied: Bool = false,
        loadsMockDataOnAppear: Bool = true)
    {
        self.viewModel = viewModel
        self.globalEnvironmentViewModel = globalEnvironmentViewModel
        self.loadsMockDataOnAppear = loadsMockDataOnAppear
        _showExportError = State(initialValue: false)
        _exportErrorMessage = State(initialValue: "")
        _isResponseCopied = State(initialValue: isResponseCopied)
        _editingEnvironment = State(initialValue: nil)
        _copyConfirmationTask = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            HSplitView {
                requestEditorView
                    .frame(minWidth: 280)
                ResponseView(
                    response: viewModel.response,
                    error: viewModel.error,
                    isExecuting: viewModel.isExecuting,
                    isCopied: isResponseCopied,
                    onCopy: copyResponse,
                    onExport: {
                        Task {
                            await exportResponse()
                        }
                    })
                    .frame(minWidth: 280)
            }
        }
        .task {
            guard loadsMockDataOnAppear else { return }

            await viewModel.loadMockData()
        }
        .onDisappear {
            copyConfirmationTask?.cancel()
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
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.editorTab.methodName)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(viewModel.editorTab.serviceName) • \(viewModel.editorTab.protoFile.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                withAnimation {
                    viewModel.toggleMetadataVisibility()
                }
            } label: {
                Label("Metadata", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .help("Toggle metadata headers editor")

            Button {
                Task {
                    await viewModel.executeRequest()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isExecuting ? "stop.fill" : "play.fill")
                    Text(viewModel.isExecuting ? "Executing" : "Execute")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(hotkeys.keyboardShortcut(for: .executeRequest))
            .disabled(viewModel.isExecuting || viewModel.url.isEmpty || viewModel.requestJson.isEmpty)

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding()
    }

    private var requestEditorView: some View {
        VSplitView {
            VStack(spacing: 0) {
                urlInputView
                Divider()
                jsonEditorView
            }
            .frame(minHeight: 200)

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
            Label(viewModel.tabEnvironment?.name ?? "Custom", systemImage: "server.rack")
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var jsonEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Request Body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let error = viewModel.requestJsonFormatError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }

                Button {
                    Task { await viewModel.resetToPreset() }
                } label: {
                    Label("Reset to Preset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
                .disabled(viewModel.isLoading)
                .help("Reset to Preset")

                Button {
                    Task { viewModel.formatRequestJson() }
                } label: {
                    Label("Format JSON", systemImage: "curlybraces")
                }
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
                .disabled(viewModel.isLoading)
                .help("Format JSON")
            }

            JSONTextEditor(
                text: Binding(
                    get: { viewModel.requestJson },
                    set: { viewModel.updateJson($0) }),
                autocompleteViewModel: viewModel.autocompleteViewModel,
                protoFile: viewModel.editorTab.protoFile)
                .id("json-editor-\(viewModel.editorTab.id)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }

    private var metadataEditorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Metadata (Headers)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("JSON format: {\"key\": \"value\"}")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let error = viewModel.metadataFormatError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { viewModel.formatMetadata() }
                } label: {
                    Label("Format JSON", systemImage: "curlybraces")
                }
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
                .disabled(viewModel.isLoading)
                .help("Format JSON")
            }

            JSONTextEditor(text: Binding(
                get: { viewModel.metadataJson },
                set: { viewModel.updateMetadata($0) }))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }

    private func copyResponse() {
        viewModel.copyResponse()
        isResponseCopied = true
        copyConfirmationTask?.cancel()
        copyConfirmationTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }

            isResponseCopied = false
        }
    }

    @MainActor
    private func exportResponse() async {
        guard let window = NSApp.keyWindow else {
            exportErrorMessage = "Unable to show save dialog"
            showExportError = true
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = viewModel.exportResponseUseCase.generateDefaultFilename()
        savePanel.canCreateDirectories = true
        savePanel.title = "Export Response"
        savePanel.message = "Choose where to save the response"

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

#if DEBUG
    #Preview("Idle", traits: .fixedLayout(width: 780, height: 664)) {
        previewRequestEditor()
    }

    #Preview("Executing", traits: .fixedLayout(width: 780, height: 664)) {
        previewRequestEditor(isExecuting: true)
    }

    #Preview("Format Error", traits: .fixedLayout(width: 780, height: 664)) {
        previewRequestEditor(
            json: "{ \"userId\": ",
            formatError: "Invalid JSON: expected property name or '}'")
    }

    #Preview("Copied", traits: .fixedLayout(width: 780, height: 664)) {
        previewRequestEditor(response: .previewSuccess, isResponseCopied: true)
    }

    #Preview("Long Content", traits: .fixedLayout(width: 780, height: 664)) {
        previewRequestEditor(
            protoFile: .previewLongNames,
            json: PreviewJSON.longDocument,
            url: "grpc.customer-facing.payments.eu-west-1.internal.example.com:443",
            environment: .previewLongName)
    }

    #Preview("Dark", traits: .fixedLayout(width: 780, height: 664)) {
        previewRequestEditor(response: .previewSuccess)
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func previewRequestEditor(
        protoFile: ProtoFile = .previewCatalog,
        json: String = PreviewJSON.shortObject,
        url: String = "localhost:50051",
        isExecuting: Bool = false,
        formatError: String? = nil,
        response: GrpcResponse? = nil,
        environment: ServerEnvironment? = .previewLocal,
        isResponseCopied: Bool = false)
        -> some View
    {
        let method = protoFile.services[0].methods[0]
        let service = protoFile.services[0]
        let editorTab = EditorTab(
            methodName: method.name,
            serviceName: service.name,
            protoFile: protoFile,
            method: method)
        let viewModel = EditorTabViewModel(
            editorTab: editorTab,
            generateMockDataUseCase: GenerateMockDataUseCase(
                mockDataGenerator: RequestEditorView_PreviewStubMockDataGenerator()),
            executeRequestUseCase: PreviewMockExecuteUseCase(),
            exportResponseUseCase: ExportResponseUseCase(fileManager: PreviewMockFileManager()),
            formatter: JsonFormatter(),
            autocompleteProvider: RequestEditorView_PreviewStubAutocompleteProvider(),
            resolver: JsonPathResolver(),
            logger: NullLogger())
        viewModel.url = url
        viewModel.requestJson = json
        viewModel.isExecuting = isExecuting
        viewModel.requestJsonFormatError = formatError
        viewModel.response = response
        let environments = [environment].compactMap(\.self)
        return RequestEditorView(
            viewModel: viewModel,
            globalEnvironmentViewModel: PreviewGlobalEnvironments.viewModel(
                environments: environments.isEmpty ? [.previewLocal] : environments,
                selected: environment),
            isResponseCopied: isResponseCopied,
            loadsMockDataOnAppear: false)
    }

    private struct RequestEditorView_PreviewStubMockDataGenerator: MockDataGeneratorProtocol {
        func generate(for _: String, in _: ProtoFile) throws -> String {
            "{}"
        }
    }

    private struct RequestEditorView_PreviewStubAutocompleteProvider: AutocompleteProviderProtocol {
        func suggestions(
            for _: AutocompleteContext,
            rootMessageType _: String,
            in _: ProtoFile)
            -> [AutocompleteSuggestion]
        {
            []
        }
    }

    private struct PreviewMockExecuteUseCase: ExecuteUnaryRequestUseCaseProtocol {
        func execute(
            request _: RequestDraft,
            method _: TrueRPCMini.Method,
            protoFile _: ProtoFile)
            throws -> GrpcResponse
        {
            .previewSuccess
        }
    }

    private struct PreviewMockFileManager: FileManagerProtocol {
        func write(_: Data, to _: URL) throws {}
    }
#endif
