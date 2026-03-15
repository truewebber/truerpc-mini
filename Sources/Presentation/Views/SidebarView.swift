import SwiftUI

/// Sidebar view displaying imported proto files and their services/methods hierarchy
public struct SidebarView: View {
    @StateObject private var viewModel: SidebarViewModel
    @EnvironmentObject private var di: AppDI
    @State private var isImporterPresented = false
    @State private var isImportPathsSheetPresented = false
    let onMethodSelected: (Method, Service, ProtoFile) -> Void
    let onSettingsOpened: () -> Void

    public init(
        viewModel: SidebarViewModel,
        onMethodSelected: @escaping (Method, Service, ProtoFile) -> Void,
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

            // Content area
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
            if isPresented { onSettingsOpened() }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading proto file...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text("Error")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No proto files imported")
                .font(.headline)
            Text("Click the + button to import a .proto file")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var protoFilesList: some View {
        List {
            ForEach(viewModel.protoFiles, id: \.path) { protoFile in
                ProtoFileRow(
                    protoFile: protoFile,
                    onMethodSelected: onMethodSelected,
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
    }

    // MARK: - Actions

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

// MARK: - ProtoFileRow

/// Row displaying a single proto file with its services and methods
private struct ProtoFileRow: View {
    let protoFile: ProtoFile
    let onMethodSelected: (Method, Service, ProtoFile) -> Void
    let onRefresh: () async -> Void
    @State private var isExpanded = true
    @State private var isHovered = false
    @State private var isRefreshing = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if protoFile.services.isEmpty {
                Text("No services found")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
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
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(isRefreshing)
                }
            }
        }
        .onHover { isHovered = $0 }
    }
}

// MARK: - ServiceRow

/// Row displaying a service with its methods
private struct ServiceRow: View {
    let service: Service
    let protoFile: ProtoFile
    let onMethodSelected: (Method, Service, ProtoFile) -> Void
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if service.methods.isEmpty {
                Text("No methods found")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(.purple)
            }
        }
    }
}

// MARK: - MethodRow

/// Row displaying a single method
private struct MethodRow: View {
    let method: Method
    let service: Service
    let protoFile: ProtoFile
    let onMethodSelected: (Method, Service, ProtoFile) -> Void

    var body: some View {
        Button {
            onMethodSelected(method, service, protoFile)
        } label: {
            HStack {
                Image(systemName: methodIcon)
                    .foregroundColor(methodColor)
                    .frame(width: 16)

                Text(method.name)
                    .font(.callout)

                Spacer()

                if method.isStreaming {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var methodIcon: String {
        method.isStreaming ? "arrow.left.arrow.right" : "arrow.right"
    }

    private var methodColor: Color {
        method.isStreaming ? .orange : .green
    }
}

// MARK: - Preview

#if DEBUG
    struct SidebarView_Previews: PreviewProvider {
        static var previewDI: AppDI {
            let di = AppDI()
            di.register(ImportPathsRepositoryProtocol.self) { UserDefaultsImportPathsRepository() }
            di.register(ImportPathsViewModel.self, lifecycle: .transient) {
                ImportPathsViewModel(importPathsRepository: di.resolve(ImportPathsRepositoryProtocol.self)!)
            }
            return di
        }

        static var previews: some View {
            // Preview with empty state
            SidebarView(
                viewModel: SidebarViewModel(
                    importProtoFileUseCase: PreviewMockUseCase(),
                    refreshProtoFileUseCase: PreviewMockRefreshUseCase(),
                    watcher: PreviewNullWatcher(),
                    importPathsRepository: PreviewMockImportPathsRepository(),
                    protoPathsPersistence: PreviewMockProtoPathsPersistence(),
                    loadSavedProtosUseCase: PreviewMockLoadSavedProtosUseCase(),
                    logger: NullLogger(),
                    telemetry: PreviewNullTelemetry()),
                onMethodSelected: { _, _, _ in })
                .environmentObject(previewDI)
                .previewDisplayName("Empty State")

            // Preview with data
            SidebarView(
                viewModel: {
                    let vm = SidebarViewModel(
                        importProtoFileUseCase: PreviewMockUseCase(),
                        refreshProtoFileUseCase: PreviewMockRefreshUseCase(),
                        watcher: PreviewNullWatcher(),
                        importPathsRepository: PreviewMockImportPathsRepository(),
                        protoPathsPersistence: PreviewMockProtoPathsPersistence(),
                        loadSavedProtosUseCase: PreviewMockLoadSavedProtosUseCase(),
                        logger: NullLogger(),
                        telemetry: PreviewNullTelemetry())
                    vm.protoFiles = [
                        ProtoFile(
                            name: "example.proto",
                            path: URL(fileURLWithPath: "/test/example.proto"),
                            services: [
                                Service(
                                    name: "UserService",
                                    methods: [
                                        Method(
                                            name: "GetUser",
                                            inputType: "GetUserRequest",
                                            outputType: "GetUserResponse",
                                            isStreaming: false),
                                        Method(
                                            name: "StreamUsers",
                                            inputType: "StreamUsersRequest",
                                            outputType: "User",
                                            isStreaming: true),
                                    ]),
                            ]),
                    ]
                    return vm
                }(),
                onMethodSelected: { _, _, _ in
                })
                .environmentObject(previewDI)
                .previewDisplayName("With Data")

            // Preview with loading state
            SidebarView(
                viewModel: {
                    let vm = SidebarViewModel(
                        importProtoFileUseCase: PreviewMockUseCase(),
                        refreshProtoFileUseCase: PreviewMockRefreshUseCase(),
                        watcher: PreviewNullWatcher(),
                        importPathsRepository: PreviewMockImportPathsRepository(),
                        protoPathsPersistence: PreviewMockProtoPathsPersistence(),
                        loadSavedProtosUseCase: PreviewMockLoadSavedProtosUseCase(),
                        logger: NullLogger(),
                        telemetry: PreviewNullTelemetry())
                    vm.isLoading = true
                    return vm
                }(),
                onMethodSelected: { _, _, _ in })
                .environmentObject(previewDI)
                .previewDisplayName("Loading")

            // Preview with error
            SidebarView(
                viewModel: {
                    let vm = SidebarViewModel(
                        importProtoFileUseCase: PreviewMockUseCase(),
                        refreshProtoFileUseCase: PreviewMockRefreshUseCase(),
                        watcher: PreviewNullWatcher(),
                        importPathsRepository: PreviewMockImportPathsRepository(),
                        protoPathsPersistence: PreviewMockProtoPathsPersistence(),
                        loadSavedProtosUseCase: PreviewMockLoadSavedProtosUseCase(),
                        logger: NullLogger(),
                        telemetry: PreviewNullTelemetry())
                    vm.error = "Failed to load proto file"
                    return vm
                }(),
                onMethodSelected: { _, _, _ in })
                .environmentObject(previewDI)
                .previewDisplayName("Error")
        }
    }

    private final class PreviewMockUseCase: ImportProtoFileUseCaseProtocol {
        func execute(url: URL) throws -> ProtoFile {
            ProtoFile(name: "test.proto", path: url, services: [])
        }

        func execute(url: URL, importPaths _: [String]) throws -> ProtoFile {
            ProtoFile(name: "test.proto", path: url, services: [])
        }
    }

    private class PreviewMockImportPathsRepository: ImportPathsRepositoryProtocol {
        func getImportPaths() -> [String] {
            []
        }

        func saveImportPaths(_: [String]) {
            // No-op for preview
        }
    }

    private class PreviewMockProtoPathsPersistence: ProtoPathsPersistenceProtocol {
        func saveProtoPaths(_: [URL]) {
            // No-op for preview
        }

        func getProtoPaths() -> [URL] {
            []
        }
    }

    private final class PreviewMockLoadSavedProtosUseCase: LoadSavedProtosUseCaseProtocol {
        func execute(urls _: [URL], importPaths _: [String]) -> [ProtoFile] {
            []
        }
    }

    private final class PreviewNullTelemetry: TelemetryServiceProtocol {
        func track(_: TelemetryEvent) {}
    }

    private final class PreviewMockRefreshUseCase: RefreshProtoFileUseCaseProtocol {
        func execute(protoFile: ProtoFile, importPaths _: [String]) throws -> ProtoFile {
            protoFile
        }
    }

    private class PreviewNullWatcher: ProtoFileWatcherProtocol {
        let changes: AsyncStream<ProtoFile> = AsyncStream { _ in }

        func startWatching(_: ProtoFile) {}
        func stopWatching(_: ProtoFile) {}
    }
#endif
