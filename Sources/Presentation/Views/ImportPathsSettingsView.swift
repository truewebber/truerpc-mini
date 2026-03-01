import SwiftUI
import UniformTypeIdentifiers

/// Settings view for managing proto import paths and analytics preferences.
public struct ImportPathsSettingsView: View {
    @ObservedObject var viewModel: ImportPathsViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var isFolderPickerPresented = false
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ImportPathsViewModel, settingsViewModel: SettingsViewModel) {
        self.viewModel = viewModel
        self.settingsViewModel = settingsViewModel
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
        .onChange(of: viewModel.dismissRequested) { _, shouldDismiss in
            guard shouldDismiss else { return }
            dismiss()
            viewModel.dismissRequested = false
        }
        .onAppear {
            settingsViewModel.onAppear()
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
            Button("Close") {
                viewModel.requestDismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            Group {
                if viewModel.paths.isEmpty {
                    emptyStateView
                } else {
                    pathsListView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            analyticsSection
        }
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

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Toggle(isOn: Binding(
                get: { settingsViewModel.isAnalyticsEnabled },
                set: { settingsViewModel.setAnalyticsEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send usage analytics")
                        .font(.body)
                    Text("Helps improve the app. No personal data is collected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
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
        ImportPathsSettingsView(
            viewModel: ImportPathsViewModel(importPathsRepository: PreviewImportPathsRepository()),
            settingsViewModel: SettingsViewModel(telemetry: PreviewNullTelemetry())
        )
        .frame(width: 450, height: 400)
    }
}

private final class PreviewNullTelemetry: TelemetryServiceProtocol {
    func track(_ event: TelemetryEvent) async {}
}

private class PreviewImportPathsRepository: ImportPathsRepositoryProtocol {
    var paths: [String] = ["/tmp/proto", "/Users/test/protos"]
    func getImportPaths() -> [String] { paths }
    func saveImportPaths(_ newPaths: [String]) { paths = newPaths }
}
#endif
