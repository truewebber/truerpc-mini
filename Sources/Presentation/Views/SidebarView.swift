import AppKit
import SwiftUI

/// Opens a method from the sidebar. `inNewTab` is set for a click with the open-in-new-tab modifiers held
/// and for "Open in New Tab"; otherwise the tab that already shows the method is selected.
public typealias MethodSelectionHandler = (Method, Service, ProtoFile, _ inNewTab: Bool) -> Void

/// Sidebar view displaying imported proto files and their services/methods hierarchy.
public struct SidebarView: View {
    @StateObject private var viewModel: SidebarViewModel
    @EnvironmentObject private var di: AppDI
    @Environment(\.hotkeys) private var hotkeys
    @State private var isImporterPresented = false
    @State private var isImportPathsSheetPresented = false
    @State private var isNewTabModifierPressed = false
    @State private var presentedImportError: PresentedImportError?
    let onMethodSelected: MethodSelectionHandler
    let onSettingsOpened: () -> Void

    public init(
        viewModel: SidebarViewModel,
        onMethodSelected: @escaping MethodSelectionHandler,
        onSettingsOpened: @escaping () -> Void = {})
    {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onMethodSelected = onMethodSelected
        self.onSettingsOpened = onSettingsOpened
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Services")
                    .font(.headline)
                Spacer()
                Button {
                    isImportPathsSheetPresented = true
                } label: {
                    if viewModel.importPathsCount > 0 {
                        Label("Import Paths (\(viewModel.importPathsCount))", systemImage: "folder.badge.gearshape")
                    } else {
                        Label("Import Paths", systemImage: "folder.badge.gearshape")
                    }
                }
                .buttonStyle(.borderless)
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Import", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            if viewModel.isLoading, !hasContracts {
                loadingView
            } else if !hasContracts {
                if let error = viewModel.error {
                    errorView(message: error)
                } else {
                    emptyStateView
                }
            } else {
                contractList
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.init(filenameExtension: "proto")!],
            allowsMultipleSelection: false)
        { result in
            handleFileImport(result: result)
        }
        .sheet(isPresented: $isImportPathsSheetPresented) {
            ImportPathsSettingsView(
                viewModel: di.resolve(ImportPathsViewModel.self)!,
                settingsViewModel: di.resolve(SettingsViewModel.self)!)
                .onDisappear {
                    viewModel.refreshImportPathsCount()
                    Task { await viewModel.retryFailedContracts() }
                }
        }
        .onChange(of: isImportPathsSheetPresented) { _, isPresented in
            if isPresented {
                onSettingsOpened()
            }
        }
        .sheet(item: $presentedImportError) { error in
            ImportErrorDetail(title: error.title, message: error.message)
        }
    }

    private func showImportError(title: String, message: String) {
        presentedImportError = PresentedImportError(title: title, message: message)
    }

    private var loadingView: some View {
        ProgressView("Loading proto file...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hasContracts: Bool {
        !viewModel.protoFiles.isEmpty || !viewModel.failedImports.isEmpty
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Could Not Load Protos", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Show Full Error") {
                showImportError(title: "Could Not Load Protos", message: message)
            }
            Button("Dismiss") {
                viewModel.error = nil
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Proto Files", systemImage: "doc.text")
        } description: {
            Text("Import a .proto file to browse its services.")
        } actions: {
            Button("Import…") {
                isImporterPresented = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contractList: some View {
        VStack(spacing: 0) {
            if let error = viewModel.error {
                noticeBanner(message: error)
            }
            protoFilesList
        }
    }

    private func noticeBanner(message: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            ImportErrorSummary(message: message, lineLimit: 2) {
                showImportError(title: "Could Not Load Protos", message: message)
            }
            Spacer(minLength: 0)
            Button("Dismiss") {
                viewModel.error = nil
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var protoFilesList: some View {
        List {
            ForEach(viewModel.protoFiles, id: \.path) { protoFile in
                ProtoFileRow(
                    protoFile: protoFile,
                    colorSlot: viewModel.contractColorSlots[protoFile.path],
                    loadError: viewModel.contractErrors[protoFile.path],
                    onShowError: { showImportError(title: protoFile.name, message: $0) },
                    onMethodSelected: { method, service, file, inNewTab in
                        onMethodSelected(method, service, file, inNewTab || isNewTabModifierPressed)
                    },
                    onRefresh: { await viewModel.refreshProtoFile(protoFile) })
                    .contextMenu {
                        if let message = viewModel.contractErrors[protoFile.path] {
                            Button("Show Full Error") {
                                showImportError(title: protoFile.name, message: message)
                            }
                            Divider()
                        }
                        Button {
                            Task { await viewModel.refreshProtoFile(protoFile) }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        Divider()
                        Button(role: .destructive) {
                            Task { await viewModel.removeProtoFile(protoFile) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let proto = viewModel.protoFiles[index]
                    Task { await viewModel.removeProtoFile(proto) }
                }
            }

            ForEach(viewModel.failedImports) { failure in
                FailedProtoRow(
                    failure: failure,
                    onRetry: { await viewModel.importProtoFile(url: failure.path) },
                    onRemove: { Task { await viewModel.removeFailedImport(failure) } },
                    onShowError: { showImportError(title: failure.name, message: failure.message) })
            }
            .onDelete { indexSet in
                let failures = indexSet.map { viewModel.failedImports[$0] }
                for failure in failures {
                    Task { await viewModel.removeFailedImport(failure) }
                }
            }
        }
        .listStyle(.sidebar)
        .onModifierKeysChanged(mask: hotkeys.openInNewTabModifiers.eventModifiers) { _, pressed in
            isNewTabModifierPressed = hotkeys.opensInNewTab(withPressed: KeyModifiers(pressed))
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            Task {
                await viewModel.importProtoFile(url: url)
            }

        case let .failure(error):
            viewModel.handlePickerError(error)
        }
    }
}

private struct ProtoFileRow: View {
    let protoFile: ProtoFile
    let colorSlot: Int?
    let loadError: String?
    let onShowError: (String) -> Void
    let onMethodSelected: MethodSelectionHandler
    let onRefresh: () async -> Void
    @State private var isExpanded = true
    @State private var isHovered = false
    @State private var isRefreshing = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if protoFile.services.isEmpty {
                Text("No services found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading)
            } else {
                ForEach(protoFile.services, id: \.name) { service in
                    ServiceRow(
                        service: service,
                        protoFile: protoFile,
                        onMethodSelected: onMethodSelected)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Label {
                        Text(protoFile.name)
                            .font(.body)
                    } icon: {
                        ContractIcon(colorSlot: colorSlot)
                    }

                    Spacer()

                    if isHovered || isRefreshing {
                        Button {
                            guard !isRefreshing else { return }

                            isRefreshing = true
                            Task {
                                await onRefresh()
                                isRefreshing = false
                            }
                        } label: {
                            if isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .labelStyle(.iconOnly)
                            }
                        }
                        .buttonStyle(.borderless)
                        .help("Refresh")
                        .disabled(isRefreshing)
                    }
                }

                if let loadError {
                    ImportErrorSummary(message: loadError, lineLimit: 2) {
                        onShowError(loadError)
                    }
                }
            }
        }
        .onHover { isHovered = $0 }
    }
}

private struct FailedProtoRow: View {
    let failure: FailedProtoImport
    let onRetry: () async -> Void
    let onRemove: () -> Void
    let onShowError: () -> Void
    @State private var isRetrying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label {
                    Text(failure.name)
                        .font(.body)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                Spacer()

                Button {
                    guard !isRetrying else { return }

                    isRetrying = true
                    Task {
                        await onRetry()
                        isRetrying = false
                    }
                } label: {
                    if isRetrying {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                    }
                }
                .buttonStyle(.borderless)
                .help("Retry")
                .disabled(isRetrying)

                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Remove")
            }

            ImportErrorSummary(message: failure.message, lineLimit: 3, onShowFullError: onShowError)
        }
        .contextMenu {
            Button("Show Full Error", action: onShowError)
            Divider()
            Button("Retry") {
                Task { await onRetry() }
            }
            Button("Remove", role: .destructive, action: onRemove)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Show Full Error", onShowError)
        .accessibilityAction(named: "Retry") {
            Task { await onRetry() }
        }
        .accessibilityAction(named: "Remove", onRemove)
    }
}

private struct PresentedImportError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// The start of an import error, with a control that opens the whole message.
private struct ImportErrorSummary: View {
    let message: String
    var lineLimit: Int = 3
    let onShowFullError: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(action: onShowFullError) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(lineLimit)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help("Show Full Error")

            Button("Show Full Error", action: onShowFullError)
                .buttonStyle(.borderless)
                .font(.caption)
                .help("Show Full Error")
        }
    }
}

/// The complete import error, scrollable and selectable so a long path can be read and copied.
private struct ImportErrorDetail: View {
    let title: String
    let message: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                Text(message)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }

            Divider()

            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message, forType: .string)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 640, height: 420)
    }
}

private struct ServiceRow: View {
    let service: Service
    let protoFile: ProtoFile
    let onMethodSelected: MethodSelectionHandler
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if service.methods.isEmpty {
                Text("No methods found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading)
            } else {
                ForEach(service.methods, id: \.name) { method in
                    MethodRow(
                        method: method,
                        service: service,
                        protoFile: protoFile,
                        onMethodSelected: onMethodSelected)
                }
            }
        } label: {
            Label {
                Text(service.name)
                    .font(.body)
            } icon: {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MethodRow: View {
    let method: Method
    let service: Service
    let protoFile: ProtoFile
    let onMethodSelected: MethodSelectionHandler
    @Environment(\.hotkeys) private var hotkeys

    var body: some View {
        Button {
            onMethodSelected(method, service, protoFile, false)
        } label: {
            HStack {
                MethodKindIcon(isStreaming: method.isStreaming)
                    .frame(width: 16)

                Text(method.name)
                    .font(.callout)

                Spacer()

                if method.isStreaming {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .help("\(hotkeys.openInNewTabModifiers.symbols)-click to open in a new tab")
        .contextMenu {
            Button("Open") { onMethodSelected(method, service, protoFile, false) }
            Button("Open in New Tab") { onMethodSelected(method, service, protoFile, true) }
        }
    }
}

#if DEBUG
    private let previewLongImportError = """
    Failed to parse /Users/truewebber/projects/services/billing/api/src/main/proto/com/example/billing/v2/orders.proto:12:8: \
    Import "com/example/billing/v2/types/money.proto" was not found or had errors.
    Searched:
    /Users/truewebber/Library/Application Support/TrueRPC Mini/import-paths/com/example/billing/v2/types/money.proto
    /Users/truewebber/projects/services/billing/api/src/main/proto/com/example/billing/v2/types/money.proto
    """

    #Preview("Empty", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar()
    }

    #Preview("Loading", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar(isLoading: true)
    }

    #Preview("Error", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar(error: "The file picker could not open the selected proto.")
    }

    #Preview("Failed Import", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar(
            files: [.previewCatalog],
            failures: [
                FailedProtoImport(
                    path: URL(fileURLWithPath: "/Users/shared/protos/orders.proto"),
                    message: previewLongImportError),
            ])
    }

    #Preview("Refresh Failed", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar(
            files: [.previewCatalog],
            contractErrors: [
                ProtoFile.previewCatalog.path: previewLongImportError,
            ])
    }

    #Preview("Error Detail", traits: .sizeThatFitsLayout) {
        ImportErrorDetail(title: "orders.proto", message: previewLongImportError)
    }

    #Preview("Error Detail Dark", traits: .sizeThatFitsLayout) {
        ImportErrorDetail(title: "orders.proto", message: previewLongImportError)
            .preferredColorScheme(.dark)
    }

    #Preview("Data", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar(files: [.previewCatalog])
    }

    #Preview("Long Content", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar(files: [.previewLongNames])
    }

    #Preview("Contracts", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar(files: PreviewContracts.all)
    }

    #Preview("Dark", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar(files: PreviewContracts.all)
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func previewSidebar(
        files: [ProtoFile] = [],
        isLoading: Bool = false,
        error: String? = nil,
        failures: [FailedProtoImport] = [],
        contractErrors: [URL: String] = [:])
        -> some View
    {
        SidebarView(
            viewModel: previewSidebarViewModel(
                files: files,
                isLoading: isLoading,
                error: error,
                failures: failures,
                contractErrors: contractErrors),
            onMethodSelected: { _, _, _, _ in },
            onSettingsOpened: {})
            .environmentObject(previewSidebarDI())
    }

    @MainActor
    private func previewSidebarViewModel(
        files: [ProtoFile],
        isLoading: Bool,
        error: String?,
        failures: [FailedProtoImport],
        contractErrors: [URL: String])
        -> SidebarViewModel
    {
        let viewModel = SidebarViewModel(
            importProtoFileUseCase: PreviewImportUseCase(),
            refreshProtoFileUseCase: PreviewRefreshUseCase(),
            watcher: PreviewNullWatcher(),
            importPathsRepository: PreviewImportPathsRepository(),
            protoPathsPersistence: PreviewProtoPathsPersistence(),
            loadSavedProtosUseCase: PreviewLoadSavedProtosUseCase(),
            assignContractColorSlotsUseCase: AssignContractColorSlotsUseCase(),
            logger: NullLogger(),
            telemetry: PreviewSidebarTelemetry())
        viewModel.protoFiles = files
        viewModel.failedImports = failures
        viewModel.contractErrors = contractErrors
        viewModel.isLoading = isLoading
        viewModel.error = error
        return viewModel
    }

    @MainActor
    private func previewSidebarDI() -> AppDI {
        let repository = PreviewImportPathsRepository()
        let di = AppDI()
        di.register(ImportPathsRepositoryProtocol.self) { repository }
        di.register(ImportPathsViewModel.self, lifecycle: .transient) {
            ImportPathsViewModel(importPathsRepository: repository)
        }
        di.register(SettingsViewModel.self, lifecycle: .transient) {
            SettingsViewModel(telemetry: PreviewSidebarTelemetry())
        }
        return di
    }

    private final class PreviewImportUseCase: ImportProtoFileUseCaseProtocol, Sendable {
        func execute(url: URL) throws -> ProtoFile {
            ProtoFile(name: "test.proto", path: url, services: [])
        }

        func execute(url: URL, importPaths _: [String]) throws -> ProtoFile {
            ProtoFile(name: "test.proto", path: url, services: [])
        }
    }

    private final class PreviewImportPathsRepository: ImportPathsRepositoryProtocol {
        func getImportPaths() -> [String] {
            []
        }

        func saveImportPaths(_: [String]) {}
    }

    private final class PreviewProtoPathsPersistence: ProtoPathsPersistenceProtocol {
        func saveProtoPaths(_: [URL]) {}

        func getProtoPaths() -> [URL] {
            []
        }
    }

    private final class PreviewLoadSavedProtosUseCase: LoadSavedProtosUseCaseProtocol, Sendable {
        func execute(urls _: [URL], importPaths _: [String]) -> SavedProtosLoadResult {
            SavedProtosLoadResult(loaded: [], failures: [])
        }
    }

    @MainActor
    private final class PreviewSidebarTelemetry: TelemetryServiceProtocol {
        func track(_: TelemetryEvent) {}
    }

    private final class PreviewRefreshUseCase: RefreshProtoFileUseCaseProtocol, Sendable {
        func execute(protoFile: ProtoFile, importPaths _: [String]) throws -> ProtoFile {
            protoFile
        }
    }

    private final class PreviewNullWatcher: ProtoFileWatcherProtocol, Sendable {
        let changes: AsyncStream<ProtoFile> = AsyncStream { $0.finish() }

        func startWatching(_: ProtoFile) {}
        func stopWatching(_: ProtoFile) {}
    }
#endif
