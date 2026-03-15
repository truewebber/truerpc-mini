import Foundation

/// Watches proto files and their transitive dependencies for on-disk changes using DispatchSource.
/// Emits the root `ProtoFile` after a 300 ms debounce so that editor write-then-truncate patterns
/// produce a single notification rather than a burst.
public final class FSEventsProtoFileWatcher: ProtoFileWatcherProtocol {
    // MARK: - Constants

    private static let debounceInterval: TimeInterval = 0.3

    // MARK: - Public

    public let changes: AsyncStream<ProtoFile>

    // MARK: - Private

    private let state: WatcherState

    // MARK: - Init / deinit

    public init() {
        var cont: AsyncStream<ProtoFile>.Continuation!
        self.changes = AsyncStream { cont = $0 }
        self.state = WatcherState(continuation: cont)
    }

    deinit {
        let st = state
        st.queue.sync {
            st.sources.values.forEach { $0.forEach { $0.cancel() } }
            st.sources.removeAll()
            st.debounceWork.values.forEach { $0.cancel() }
            st.debounceWork.removeAll()
        }
        state.continuation.finish()
    }

    // MARK: - ProtoFileWatcherProtocol

    public func startWatching(_ protoFile: ProtoFile) {
        let st = state
        st.queue.async {
            cancelAndRemove(protoFile.path, in: st)

            let urlsToWatch = [protoFile.path] + protoFile.dependencyPaths
            var fileSources: [any DispatchSourceFileSystemObject] = []

            for url in urlsToWatch {
                let fd = open(url.path, O_EVTONLY)
                guard fd >= 0 else { continue }

                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .rename, .delete],
                    queue: st.queue)

                source.setEventHandler { scheduleEmit(
                    protoFile,
                    in: st,
                    debounce: FSEventsProtoFileWatcher.debounceInterval) }
                source.setCancelHandler { close(fd) }
                source.resume()
                fileSources.append(source)
            }

            if !fileSources.isEmpty {
                st.sources[protoFile.path] = fileSources
            }
        }
    }

    public func stopWatching(_ protoFile: ProtoFile) {
        let st = state
        st.queue.async {
            cancelAndRemove(protoFile.path, in: st)
        }
    }
}

// MARK: - State helpers (free functions to avoid self capture)

private func cancelAndRemove(_ rootURL: URL, in state: WatcherState) {
    state.debounceWork[rootURL]?.cancel()
    state.debounceWork[rootURL] = nil
    state.sources.removeValue(forKey: rootURL)?.forEach { $0.cancel() }
}

private func scheduleEmit(_ protoFile: ProtoFile, in state: WatcherState, debounce: TimeInterval) {
    state.debounceWork[protoFile.path]?.cancel()
    let work = DispatchWorkItem { state.continuation.yield(protoFile) }
    state.debounceWork[protoFile.path] = work
    state.queue.asyncAfter(deadline: .now() + debounce, execute: work)
}

// MARK: - Internal mutable state

/// All mutable watcher state, serialised exclusively on `queue`.
/// @unchecked Sendable is justified because:
///   - This is a private implementation detail, never exposed in the public API.
///   - Every mutation is guarded by the serial `queue` (all code paths dispatch to it).
private final class WatcherState: @unchecked Sendable {
    let queue = DispatchQueue(label: "com.truerpc.fswatcher", attributes: [])
    let continuation: AsyncStream<ProtoFile>.Continuation
    var sources: [URL: [any DispatchSourceFileSystemObject]] = [:]
    var debounceWork: [URL: DispatchWorkItem] = [:]

    init(continuation: AsyncStream<ProtoFile>.Continuation) {
        self.continuation = continuation
    }
}
