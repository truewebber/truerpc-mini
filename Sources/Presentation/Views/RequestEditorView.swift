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
        func suggestions(
            for _: AutocompleteContext,
            rootMessageType _: String,
            in _: ProtoFile)
            -> [AutocompleteSuggestion]
        {
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

        textView.setAccessibilityIdentifier("json_editor")
        textView.delegate = context.coordinator
        textView.string = text
        context.coordinator.textView = textView

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
        weak var textView: NSTextView?

        /// Tracks the most recent pending context-update task spawned after a text change.
        /// Cancelled on explicit suggestion commit or Escape so the popover is not re-opened
        /// by a stale task after an intentional dismiss.
        private var pendingUpdateTask: Task<Void, Never>?

        /// Suppresses autocomplete re-trigger while smart-insert modifies the text view.
        private var suppressTextDidChange = false

        init(_ parent: JSONTextEditor) {
            self.parent = parent
        }

        /// UTF-16 code units for JSON structural ASCII (NSString.character(at:)).
        private enum JsonScanUTF16 {
            static let quote: UInt16 = 0x22
            static let backslash: UInt16 = 0x5C
            static let bracketOpen: UInt16 = 0x5B
            static let bracketClose: UInt16 = 0x5D
            static let braceOpen: UInt16 = 0x7B
            static let braceClose: UInt16 = 0x7D
            static let space: UInt16 = 0x20
            static let lf: UInt16 = 0x0A
            static let cr: UInt16 = 0x0D
            static let tab: UInt16 = 0x09
            static let comma: UInt16 = 0x2C
            static let colon: UInt16 = 0x3A
        }

        /// Single NSPopover instance owned by this coordinator.
        /// .applicationDefined prevents AppKit from auto-closing it on the next keystroke.
        lazy var autocompletePopover: NSPopover = {
            let popover = NSPopover()
            popover.behavior = .applicationDefined
            popover.animates = false
            if let vm = parent.autocompleteViewModel {
                let hostingController = NSHostingController(
                    rootView: AutocompletePopoverView(
                        viewModel: vm,
                        onRowTapped: { [weak self] suggestion in
                            self?.commitSuggestion(suggestion, vm: vm)
                        },
                        onEscape: { [weak self] in
                            self?.pendingUpdateTask?.cancel()
                            vm.dismiss()
                            self?.autocompletePopover.close()
                        }))
                hostingController.view.setAccessibilityIdentifier("autocomplete_popover")
                popover.contentViewController = hostingController
            }
            return popover
        }()

        // MARK: NSTextViewDelegate — text changes

        nonisolated func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            MainActor.assumeIsolated {
                let text = textView.string
                parent.text = text

                guard !suppressTextDidChange else { return }

                let cursorOffset = textView.selectedRange().location

                guard let vm = parent.autocompleteViewModel,
                      let protoFile = parent.protoFile
                else { return }

                pendingUpdateTask?.cancel()
                pendingUpdateTask = Task { @MainActor [weak textView] in
                    await vm.textDidChange(text, cursorOffset: cursorOffset, protoFile: protoFile)
                    guard !Task.isCancelled else { return }
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

                case #selector(NSTextView.insertTab(_:)):
                    guard let suggestion = vm.commitSelection() else { return false }

                    if suggestion.kind == .fillDefaults {
                        pendingUpdateTask?.cancel()
                        Task { await vm.fillDefaultsHandler?() }
                        vm.dismiss()
                        autocompletePopover.close()
                        return true
                    }

                    applySmartInsert(suggestion: suggestion, to: textView)
                    postInsertUpdate(suggestion: suggestion, textView: textView, vm: vm)
                    return true

                case #selector(NSTextView.insertNewline(_:)):
                    pendingUpdateTask?.cancel()
                    vm.dismiss()
                    autocompletePopover.close()
                    suppressTextDidChange = true
                    DispatchQueue.main.async { self.suppressTextDidChange = false }
                    return false

                case #selector(NSResponder.cancelOperation(_:)):
                    pendingUpdateTask?.cancel()
                    vm.dismiss()
                    autocompletePopover.close()
                    return true

                default:
                    return false
                }
            }
        }

        // MARK: - Suggestion commit (keyboard + mouse)

        /// Commits a suggestion received from the popover (mouse click or popover keyboard shortcut).
        /// Handles both `fillDefaults` (triggers `resetToPreset`) and regular insertions.
        private func commitSuggestion(_ suggestion: AutocompleteSuggestion, vm: AutocompleteViewModel) {
            if suggestion.kind == .fillDefaults {
                pendingUpdateTask?.cancel()
                Task { await vm.fillDefaultsHandler?() }
                vm.dismiss()
                autocompletePopover.close()
                return
            }

            guard let tv = textView else { return }

            applySmartInsert(suggestion: suggestion, to: tv)
            postInsertUpdate(suggestion: suggestion, textView: tv, vm: vm)
        }

        /// After inserting a suggestion, either re-trigger autocomplete (for compound types
        /// where the cursor lands inside `{}` or `[]`) or dismiss the popover.
        private func postInsertUpdate(
            suggestion: AutocompleteSuggestion,
            textView: NSTextView,
            vm: AutocompleteViewModel)
        {
            let continueAutocomplete = suggestion.kind == .message || suggestion.kind == .repeated

            if continueAutocomplete, let protoFile = parent.protoFile {
                let newText = textView.string
                let offset = textView.selectedRange().location
                pendingUpdateTask?.cancel()
                pendingUpdateTask = Task { @MainActor [weak textView] in
                    await vm.textDidChange(newText, cursorOffset: offset, protoFile: protoFile)
                    guard !Task.isCancelled else { return }
                    guard let textView else { return }

                    if vm.isVisible {
                        self.showPopoverIfNeeded(in: textView)
                    } else {
                        self.autocompletePopover.close()
                    }
                }
            } else {
                pendingUpdateTask?.cancel()
                vm.dismiss()
                autocompletePopover.close()
            }
        }

        // MARK: - Popover positioning

        private func showPopoverIfNeeded(in textView: NSTextView) {
            guard let window = textView.window else { return }

            let range = textView.selectedRange()
            let rect = cursorViewRect(in: textView, range: range, window: window)

            if autocompletePopover.isShown {
                autocompletePopover.close()
            }
            autocompletePopover.show(relativeTo: rect, of: textView, preferredEdge: .maxY)
            window.makeFirstResponder(textView)
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

        /// Applies a replacement without querying `shouldChangeText`, which can reject programmatic
        /// auto-closing edits in headless `NSTextView` instances (e.g. integration tests).
        private static func replaceInTextViewWithoutShouldChangeGate(
            _ textView: NSTextView,
            range: NSRange,
            string: String)
        {
            guard let storage = textView.textStorage else {
                textView.replaceCharacters(in: range, with: string)
                textView.didChangeText()
                return
            }

            storage.beginEditing()
            storage.replaceCharacters(in: range, with: string)
            storage.endEditing()
            textView.didChangeText()
        }

        /// Internal for `@testable` integration tests (keyboard path also calls this).
        func applySmartInsert(suggestion: AutocompleteSuggestion, to textView: NSTextView) {
            let (insertText, cursorBack) = Self.smartInsertComponents(for: suggestion)
            guard !insertText.isEmpty else { return }

            let range = textView.selectedRange()
            if textView.shouldChangeText(in: range, replacementString: insertText) {
                suppressTextDidChange = true
                defer { suppressTextDidChange = false }

                let lengthBefore = (textView.string as NSString).length
                textView.replaceCharacters(in: range, with: insertText)
                textView.didChangeText()
                let lengthAfter = (textView.string as NSString).length
                // Use the actual UTF-16 length delta — `NSTextView` may normalize newlines/quotes so
                // `insertText.utf16.count` does not match what was stored (breaks bracket math in tests
                // and edge cases).
                let insertedUTF16Count = lengthAfter - lengthBefore + range.length
                let insertEnd = range.location + insertedUTF16Count
                let nsFull = textView.string as NSString
                let pendingArrays = Self.arrayBracketBalanceInPrefix(ns: nsFull, endUTF16: insertEnd)
                let nextSig = Self.nextSignificantUTF16IndexAndScalar(ns: nsFull, fromUTF16: insertEnd)

                if pendingArrays > 0,
                   let next = nextSig,
                   next.scalar == JsonScanUTF16.bracketClose,
                   let closeBracket = Self.indexOfClosingBracketForContainingArray(ns: nsFull, fromUTF16: insertEnd),
                   next.index == closeBracket,
                   let openBracket = Self.indexOfMatchingOpenBracket(ns: nsFull, closingBracketUTF16: closeBracket)
                {
                    let innerBraces = Self.netBraceCountInUTF16Range(
                        ns: nsFull,
                        fromUTF16: openBracket + 1,
                        toUTF16: insertEnd)
                    if innerBraces > 0 {
                        let patch = String(repeating: "\n}", count: innerBraces)
                        // Close the object(s) immediately after the new field — not before `]`, or
                        // whitespace between the value and `]` ends up *inside* the closing brace
                        // (e.g. `"id": ""\n  \n}]` instead of `"id": ""\n}\n  ]`).
                        Self.replaceInTextViewWithoutShouldChangeGate(
                            textView,
                            range: NSRange(location: insertEnd, length: 0),
                            string: patch)
                    }
                } else {
                    let missingMiddle = Self.unclosedBraceCount(in: textView.string)
                    let skipMiddleInsertion = nextSig.map { pair in
                        pair.scalar == JsonScanUTF16.comma || pair.scalar == JsonScanUTF16.colon
                    } ?? false
                    if !skipMiddleInsertion, missingMiddle > 1 {
                        let patch = String(repeating: "\n}", count: missingMiddle - 1)
                        Self.replaceInTextViewWithoutShouldChangeGate(
                            textView,
                            range: NSRange(location: insertEnd, length: 0),
                            string: patch)
                    }
                }

                let cursorPos = insertEnd - cursorBack

                let missingTrailing = Self.unclosedBraceCount(in: textView.string)
                if missingTrailing == 1 {
                    let suffix = "\n}"
                    let endRange = NSRange(location: textView.string.utf16.count, length: 0)
                    Self.replaceInTextViewWithoutShouldChangeGate(textView, range: endRange, string: suffix)
                }

                parent.text = textView.string
                textView.setSelectedRange(NSRange(location: max(0, cursorPos), length: 0))
            }
        }

        /// Counts `[` minus `]` outside of JSON string literals in `text[..<endUTF16]`.
        static func arrayBracketBalanceInPrefix(ns: NSString, endUTF16: Int) -> Int {
            var balance = 0
            var inString = false
            var escaped = false
            let length = min(endUTF16, ns.length)
            var i = 0
            while i < length {
                let c = ns.character(at: i)
                if escaped {
                    escaped = false
                    i += 1
                    continue
                }
                if inString {
                    if c == JsonScanUTF16.backslash { escaped = true }
                    else if c == JsonScanUTF16.quote { inString = false }
                    i += 1
                    continue
                }
                if c == JsonScanUTF16.quote {
                    inString = true
                    i += 1
                    continue
                }
                if c == JsonScanUTF16.bracketOpen { balance += 1 }
                else if c == JsonScanUTF16.bracketClose { balance -= 1 }
                i += 1
            }
            return balance
        }

        /// First non-whitespace UTF-16 index at/after `fromUTF16`, or nil if EOF.
        static func nextSignificantUTF16IndexAndScalar(ns: NSString, fromUTF16: Int) -> (index: Int, scalar: UInt16)? {
            var i = fromUTF16
            while i < ns.length {
                let c = ns.character(at: i)
                if c == JsonScanUTF16.space || c == JsonScanUTF16.lf || c == JsonScanUTF16.cr
                    || c == JsonScanUTF16.tab
                {
                    i += 1
                    continue
                }
                return (i, c)
            }
            return nil
        }

        /// The `]` that closes the innermost array still open at `fromUTF16` (skips strings).
        static func indexOfClosingBracketForContainingArray(ns: NSString, fromUTF16: Int) -> Int? {
            var pending = arrayBracketBalanceInPrefix(ns: ns, endUTF16: fromUTF16)
            guard pending > 0 else { return nil }

            var inString = false
            var escaped = false
            var i = fromUTF16
            let length = ns.length
            while i < length {
                let c = ns.character(at: i)
                if escaped {
                    escaped = false
                    i += 1
                    continue
                }
                if inString {
                    if c == JsonScanUTF16.backslash { escaped = true }
                    else if c == JsonScanUTF16.quote { inString = false }
                    i += 1
                    continue
                }
                if c == JsonScanUTF16.quote {
                    inString = true
                    i += 1
                    continue
                }
                if c == JsonScanUTF16.bracketOpen {
                    pending += 1
                } else if c == JsonScanUTF16.bracketClose {
                    pending -= 1
                    if pending == 0 { return i }
                }
                i += 1
            }
            return nil
        }

        /// Matching `[` index for `]` at `closingBracketUTF16` (prefix `0..<closing`).
        static func indexOfMatchingOpenBracket(ns: NSString, closingBracketUTF16: Int) -> Int? {
            var stack: [Int] = []
            var inString = false
            var escaped = false
            var i = 0
            while i < closingBracketUTF16 {
                let c = ns.character(at: i)
                if escaped {
                    escaped = false
                    i += 1
                    continue
                }
                if inString {
                    if c == JsonScanUTF16.backslash { escaped = true }
                    else if c == JsonScanUTF16.quote { inString = false }
                    i += 1
                    continue
                }
                if c == JsonScanUTF16.quote {
                    inString = true
                    i += 1
                    continue
                }
                if c == JsonScanUTF16.bracketOpen {
                    stack.append(i)
                } else if c == JsonScanUTF16.bracketClose {
                    _ = stack.popLast()
                }
                i += 1
            }
            return stack.last
        }

        /// Counts `{` minus `}` in `[fromUTF16, toUTF16)` outside of string literals.
        static func netBraceCountInUTF16Range(ns: NSString, fromUTF16: Int, toUTF16: Int) -> Int {
            var balance = 0
            var inString = false
            var escaped = false
            var i = fromUTF16
            let end = min(toUTF16, ns.length)
            while i < end {
                let c = ns.character(at: i)
                if escaped {
                    escaped = false
                    i += 1
                    continue
                }
                if inString {
                    if c == JsonScanUTF16.backslash { escaped = true }
                    else if c == JsonScanUTF16.quote { inString = false }
                    i += 1
                    continue
                }
                if c == JsonScanUTF16.quote {
                    inString = true
                    i += 1
                    continue
                }
                if c == JsonScanUTF16.braceOpen { balance += 1 }
                else if c == JsonScanUTF16.braceClose { balance -= 1 }
                i += 1
            }
            return max(0, balance)
        }

        /// Counts `{` minus `}` outside of JSON string literals.
        static func unclosedBraceCount(in text: String) -> Int {
            var balance = 0
            var inString = false
            var escaped = false

            for char in text {
                if escaped { escaped = false
                    continue
                }
                if char == "\\", inString { escaped = true
                    continue
                }
                if char == "\"" { inString.toggle()
                    continue
                }
                guard !inString else { continue }

                if char == "{" { balance += 1 }
                else if char == "}" { balance -= 1 }
            }

            return max(0, balance)
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
