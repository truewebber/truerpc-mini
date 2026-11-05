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
            allowsMultipleSelection: false)
        { result in
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

    @ViewBuilder
    private var contentView: some View {
        if viewModel.paths.isEmpty {
            emptyStateView
        } else {
            pathsListView
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Import Paths", systemImage: "folder")
        } description: {
            Text("Add folders to resolve proto file dependencies.")
        } actions: {
            Button("Add Folder…") {
                isFolderPickerPresented = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pathsListView: some View {
        List {
            ForEach(Array(viewModel.paths.enumerated()), id: \.offset) { index, path in
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text(path)
                        .font(.body.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(role: .destructive) {
                        viewModel.removePath(at: index)
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove")
                }
            }
        }
        .listStyle(.inset)
    }

    private func handleFolderImport(result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }

            viewModel.addPath(url: url)

        case .failure:
            break
        }
    }
}

#if DEBUG
    #Preview("Empty", traits: .fixedLayout(width: 480, height: 420)) {
        previewImportPathsSettings(paths: [])
    }

    #Preview("Paths", traits: .fixedLayout(width: 480, height: 420)) {
        previewImportPathsSettings(paths: ["/tmp/proto", "/Users/test/protos"])
    }

    #Preview("Long Content", traits: .fixedLayout(width: 480, height: 420)) {
        previewImportPathsSettings(paths: [
            "/Users/shared/proto-includes/third-party/googleapis/google/cloud/billing/v1/customer_billing_and_subscription_admin",
        ])
    }

    #Preview("Dark", traits: .fixedLayout(width: 480, height: 420)) {
        previewImportPathsSettings(paths: ["/tmp/proto", "/Users/test/protos"])
            .preferredColorScheme(.dark)
    }

    @MainActor
    private func previewImportPathsSettings(paths: [String]) -> some View {
        ImportPathsSettingsView(
            viewModel: ImportPathsViewModel(
                importPathsRepository: PreviewImportPathsRepository(paths: paths)),
            settingsViewModel: SettingsViewModel(telemetry: PreviewSettingsTelemetry()))
    }

    @MainActor
    private final class PreviewSettingsTelemetry: TelemetryServiceProtocol {
        func track(_: TelemetryEvent) {}
    }

    private final class PreviewImportPathsRepository: ImportPathsRepositoryProtocol {
        var paths: [String]

        init(paths: [String]) {
            self.paths = paths
        }

        func getImportPaths() -> [String] {
            paths
        }

        func saveImportPaths(_ newPaths: [String]) {
            paths = newPaths
        }
    }
#endif
