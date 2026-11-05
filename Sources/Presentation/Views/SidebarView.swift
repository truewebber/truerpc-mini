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

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(message: error)
            } else if viewModel.protoFiles.isEmpty {
                emptyStateView
            } else {
                protoFilesList
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
                }
        }
        .onChange(of: isImportPathsSheetPresented) { _, isPresented in
            if isPresented {
                onSettingsOpened()
            }
        }
    }

    private var loadingView: some View {
        ProgressView("Loading proto file...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label("Could Not Load Protos", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
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

    private var protoFilesList: some View {
        List {
            ForEach(viewModel.protoFiles, id: \.path) { protoFile in
                ProtoFileRow(
                    protoFile: protoFile,
                    colorSlot: viewModel.contractColorSlots[protoFile.path],
                    onMethodSelected: { method, service, file, inNewTab in
                        onMethodSelected(method, service, file, inNewTab || isNewTabModifierPressed)
                    },
                    onRefresh: { await viewModel.refreshProtoFile(protoFile) })
                    .contextMenu {
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
        }
        .onHover { isHovered = $0 }
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
    #Preview("Empty", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar()
    }

    #Preview("Loading", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar(isLoading: true)
    }

    #Preview("Error", traits: .fixedLayout(width: 320, height: 700)) {
        previewSidebar(error: "Failed to load proto file: missing import \"google/protobuf/timestamp.proto\".")
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
        error: String? = nil)
        -> some View
    {
        SidebarView(
            viewModel: previewSidebarViewModel(files: files, isLoading: isLoading, error: error),
            onMethodSelected: { _, _, _, _ in },
            onSettingsOpened: {})
            .environmentObject(previewSidebarDI())
    }

    @MainActor
    private func previewSidebarViewModel(
        files: [ProtoFile],
        isLoading: Bool,
        error: String?)
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
        func execute(urls _: [URL], importPaths _: [String]) -> [ProtoFile] {
            []
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
