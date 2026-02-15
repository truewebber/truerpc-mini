import SwiftUI

/// Sidebar view displaying imported proto files and their services/methods hierarchy
public struct SidebarView: View {
    @StateObject private var viewModel: SidebarViewModel
    @State private var isImporterPresented = false
    let onMethodSelected: (Method, Service, ProtoFile) -> Void
    
    public init(
        viewModel: SidebarViewModel,
        onMethodSelected: @escaping (Method, Service, ProtoFile) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onMethodSelected = onMethodSelected
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with Import button
            HStack {
                Text("Services")
                    .font(.headline)
                Spacer()
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
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
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
                    onMethodSelected: onMethodSelected
                )
            }
        }
        .listStyle(.sidebar)
    }
    
    // MARK: - Actions
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await viewModel.importProtoFile(url: url)
            }
        case .failure(let error):
            viewModel.error = error.localizedDescription
        }
    }
}

// MARK: - ProtoFileRow

/// Row displaying a single proto file with its services and methods
private struct ProtoFileRow: View {
    let protoFile: ProtoFile
    let onMethodSelected: (Method, Service, ProtoFile) -> Void
    @State private var isExpanded = true
    
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
                        onMethodSelected: onMethodSelected
                    )
                }
            }
        } label: {
            Label {
                Text(protoFile.name)
                    .font(.body)
            } icon: {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
            }
        }
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
                        onMethodSelected: onMethodSelected
                    )
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
    static var previews: some View {
        // Preview with empty state
        SidebarView(
            viewModel: SidebarViewModel(
                importProtoFileUseCase: PreviewMockUseCase(),
                importPathsRepository: PreviewMockImportPathsRepository(),
                protoPathsPersistence: PreviewMockProtoPathsPersistence(),
                loadSavedProtosUseCase: PreviewMockLoadSavedProtosUseCase()
            ),
            onMethodSelected: { _, _, _ in }
        )
        .previewDisplayName("Empty State")
        
        // Preview with data
        SidebarView(
            viewModel: {
                let vm = SidebarViewModel(
                    importProtoFileUseCase: PreviewMockUseCase(),
                    importPathsRepository: PreviewMockImportPathsRepository(),
                    protoPathsPersistence: PreviewMockProtoPathsPersistence(),
                    loadSavedProtosUseCase: PreviewMockLoadSavedProtosUseCase()
                )
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
                                        isStreaming: false
                                    ),
                                    Method(
                                        name: "StreamUsers",
                                        inputType: "StreamUsersRequest",
                                        outputType: "User",
                                        isStreaming: true
                                    )
                                ]
                            )
                        ]
                    )
                ]
                return vm
            }(),
            onMethodSelected: { method, service, protoFile in
                print("Selected: \(method.name) from \(service.name)")
            }
        )
        .previewDisplayName("With Data")
        
        // Preview with loading state
        SidebarView(
            viewModel: {
                let vm = SidebarViewModel(
                    importProtoFileUseCase: PreviewMockUseCase(),
                    importPathsRepository: PreviewMockImportPathsRepository(),
                    protoPathsPersistence: PreviewMockProtoPathsPersistence(),
                    loadSavedProtosUseCase: PreviewMockLoadSavedProtosUseCase()
                )
                vm.isLoading = true
                return vm
            }(),
            onMethodSelected: { _, _, _ in }
        )
        .previewDisplayName("Loading")
        
        // Preview with error
        SidebarView(
            viewModel: {
                let vm = SidebarViewModel(
                    importProtoFileUseCase: PreviewMockUseCase(),
                    importPathsRepository: PreviewMockImportPathsRepository(),
                    protoPathsPersistence: PreviewMockProtoPathsPersistence(),
                    loadSavedProtosUseCase: PreviewMockLoadSavedProtosUseCase()
                )
                vm.error = "Failed to load proto file"
                return vm
            }(),
            onMethodSelected: { _, _, _ in }
        )
        .previewDisplayName("Error")
    }
}

private class PreviewMockUseCase: ImportProtoFileUseCaseProtocol {
    func execute(url: URL) async throws -> ProtoFile {
        ProtoFile(name: "test.proto", path: url, services: [])
    }
    
    func execute(url: URL, importPaths: [String]) async throws -> ProtoFile {
        ProtoFile(name: "test.proto", path: url, services: [])
    }
}

private class PreviewMockImportPathsRepository: ImportPathsRepositoryProtocol {
    func getImportPaths() -> [String] {
        return []
    }
    
    func saveImportPaths(_ paths: [String]) {
        // No-op for preview
    }
}

private class PreviewMockProtoPathsPersistence: ProtoPathsPersistenceProtocol {
    func saveProtoPaths(_ paths: [URL]) {
        // No-op for preview
    }
    
    func getProtoPaths() -> [URL] {
        return []
    }
}

private class PreviewMockLoadSavedProtosUseCase: LoadSavedProtosUseCase {
    init() {
        super.init(importProtoFileUseCase: PreviewMockUseCase())
    }
    
    override func execute(urls: [URL], importPaths: [String]) async -> [ProtoFile] {
        return []
    }
}
#endif

