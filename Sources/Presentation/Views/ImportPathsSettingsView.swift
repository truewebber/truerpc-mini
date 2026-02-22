import SwiftUI
import UniformTypeIdentifiers

/// Settings view for managing proto import paths
/// Used to resolve dependencies when loading .proto files
public struct ImportPathsSettingsView: View {
    @ObservedObject var viewModel: ImportPathsViewModel
    @State private var isFolderPickerPresented = false

    public init(viewModel: ImportPathsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .frame(minWidth: 400, minHeight: 300)
        .fileImporter(
            isPresented: $isFolderPickerPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderImport(result: result)
        }
    }

    private var headerView: some View {
        HStack {
            Text("Import Paths")
                .font(.headline)
            Spacer()
            Button {
                isFolderPickerPresented = true
            } label: {
                Label("Add Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var contentView: some View {
        Group {
            if viewModel.paths.isEmpty {
                emptyStateView
            } else {
                pathsListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No import paths")
                .font(.headline)
            Text("Add folders to resolve proto file dependencies")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pathsListView: some View {
        List {
            ForEach(Array(viewModel.paths.enumerated()), id: \.offset) { index, path in
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    Text(path)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(role: .destructive) {
                        viewModel.removePath(at: index)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .listStyle(.inset)
    }

    private func handleFolderImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            viewModel.addPath(url: url)
        case .failure:
            break
        }
    }
}

#if DEBUG
struct ImportPathsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ImportPathsSettingsView(viewModel: ImportPathsViewModel(importPathsRepository: PreviewImportPathsRepository()))
            .frame(width: 450, height: 350)
    }
}

private class PreviewImportPathsRepository: ImportPathsRepositoryProtocol {
    var paths: [String] = ["/tmp/proto", "/Users/test/protos"]
    func getImportPaths() -> [String] { paths }
    func saveImportPaths(_ newPaths: [String]) { paths = newPaths }
}
#endif
