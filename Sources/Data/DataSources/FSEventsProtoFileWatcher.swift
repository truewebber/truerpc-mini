import Foundation

/// Watches proto files and their transitive dependencies for on-disk changes using DispatchSource.
/// Emits the root `ProtoFile` after a 300 ms debounce so that editor write-then-truncate patterns
/// produce a single notification rather than a burst.
/// Thread-safe: all state mutations are serialised onto a private DispatchQueue.
public final class FSEventsProtoFileWatcher: ProtoFileWatcherProtocol {
    // MARK: - Constants

    private static let debounceInterval: TimeInterval = 0.3

    // MARK: - Public

    public let changes: AsyncStream<ProtoFile>

    // MARK: - Private

    private let queue = DispatchQueue(label: "com.truerpc.fswatcher", attributes: [])
    private var sources: [URL: [DispatchSourceFileSystemObject]] = [:]
    private var debounceWork: [URL: DispatchWorkItem] = [:]
    private let continuation: AsyncStream<ProtoFile>.Continuation

    // MARK: - Init / deinit

    public init() {
        var cont: AsyncStream<ProtoFile>.Continuation!
        self.changes = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    deinit {
        queue.sync {
            for fileSources in sources.values {
                fileSources.forEach { $0.cancel() }
            }
            sources.removeAll()
            for work in debounceWork.values {
                work.cancel()
            }
            debounceWork.removeAll()
        }
        continuation.finish()
    }

    // MARK: - ProtoFileWatcherProtocol

    public func startWatching(_ protoFile: ProtoFile) {
        queue.async { [weak self] in
            guard let self else { return }

            cancelAndRemove(for: protoFile.path)

            let urlsToWatch = [protoFile.path] + protoFile.dependencyPaths
            var fileSources: [DispatchSourceFileSystemObject] = []

            for url in urlsToWatch {
                let fd = open(url.path, O_EVTONLY)
                guard fd >= 0 else { continue }

                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .rename, .delete],
                    queue: queue)

                source.setEventHandler { [weak self] in
                    self?.scheduleEmit(protoFile)
                }
                source.setCancelHandler { close(fd) }
                source.resume()
                fileSources.append(source)
            }

            if !fileSources.isEmpty {
                sources[protoFile.path] = fileSources
            }
        }
    }

    public func stopWatching(_ protoFile: ProtoFile) {
        queue.async { [weak self] in
            self?.cancelAndRemove(for: protoFile.path)
        }
    }

    // MARK: - Private helpers

    private func cancelAndRemove(for rootURL: URL) {
        debounceWork[rootURL]?.cancel()
        debounceWork[rootURL] = nil
        if let fileSources = sources.removeValue(forKey: rootURL) {
            fileSources.forEach { $0.cancel() }
        }
    }

    private func scheduleEmit(_ protoFile: ProtoFile) {
        debounceWork[protoFile.path]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.continuation.yield(protoFile)
        }
        debounceWork[protoFile.path] = work
        queue.asyncAfter(deadline: .now() + Self.debounceInterval, execute: work)
    }
}
