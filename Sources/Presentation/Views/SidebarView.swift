import SwiftUI

/// Sidebar view displaying imported proto files and their services/methods hierarchy
public struct SidebarView: View {
    @StateObject private var viewModel: SidebarViewModel
    @State private var isImporterPresented = false
    
    public init(viewModel: SidebarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                ProtoFileRow(protoFile: protoFile)
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
                    ServiceRow(service: service)
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
                    MethodRow(method: method)
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
    
    var body: some View {
        Button {
            // TODO: Handle method selection in Epic 3
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
        SidebarView(viewModel: SidebarViewModel(
            importProtoFileUseCase: PreviewMockUseCase(),
            importPathsRepository: PreviewMockImportPathsRepository()
        ))
        .previewDisplayName("Empty State")
        
        // Preview with data
        SidebarView(viewModel: {
            let vm = SidebarViewModel(
                importProtoFileUseCase: PreviewMockUseCase(),
                importPathsRepository: PreviewMockImportPathsRepository()
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
        }())
        .previewDisplayName("With Data")
        
        // Preview with loading state
        SidebarView(viewModel: {
            let vm = SidebarViewModel(
                importProtoFileUseCase: PreviewMockUseCase(),
                importPathsRepository: PreviewMockImportPathsRepository()
            )
            vm.isLoading = true
            return vm
        }())
        .previewDisplayName("Loading")
        
        // Preview with error
        SidebarView(viewModel: {
            let vm = SidebarViewModel(
                importProtoFileUseCase: PreviewMockUseCase(),
                importPathsRepository: PreviewMockImportPathsRepository()
            )
            vm.error = "Failed to load proto file"
            return vm
        }())
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
#endif

