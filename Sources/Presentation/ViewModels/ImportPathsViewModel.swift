import Foundation
import SwiftUI

/// ViewModel for managing import paths settings UI
@MainActor
public final class ImportPathsViewModel: ObservableObject {

    @Published public private(set) var paths: [String] = []
    @Published public var dismissRequested: Bool = false

    private let importPathsRepository: ImportPathsRepositoryProtocol

    public init(importPathsRepository: ImportPathsRepositoryProtocol) {
        self.importPathsRepository = importPathsRepository
        self.paths = importPathsRepository.getImportPaths()
    }

    public func addPath(url: URL) {
        let path = url.path
        guard !path.isEmpty, !paths.contains(path) else { return }
        paths.append(path)
        importPathsRepository.saveImportPaths(paths)
    }

    public func removePath(at index: Int) {
        guard index >= 0, index < paths.count else { return }
        paths.remove(at: index)
        importPathsRepository.saveImportPaths(paths)
    }

    public func requestDismiss() {
        dismissRequested = true
    }
}
