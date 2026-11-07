import Foundation

/// A proto file the user added that could not be parsed.
///
/// It stays in the sidebar, so the other contracts remain usable and this one can be removed or retried later.
public struct FailedProtoImport: Equatable, Identifiable, Sendable {
    public let path: URL
    public let message: String

    public var id: URL {
        path
    }

    public var name: String {
        path.lastPathComponent
    }

    public init(path: URL, message: String) {
        self.path = path
        self.message = message
    }
}

/// Proto files restored from saved paths, split into the ones that parsed and the ones that did not.
public struct SavedProtosLoadResult: Equatable, Sendable {
    public let loaded: [ProtoFile]
    public let failures: [FailedProtoImport]

    public init(loaded: [ProtoFile], failures: [FailedProtoImport]) {
        self.loaded = loaded
        self.failures = failures
    }
}
