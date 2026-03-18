import Foundation
import os
@testable import TrueRPCMini

final class MockProtoFileWatcher: ProtoFileWatcherProtocol, Sendable {
    private struct Storage {
        var startWatchingCalls: [ProtoFile] = []
        var stopWatchingCalls: [ProtoFile] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())
    private let _continuation: AsyncStream<ProtoFile>.Continuation
    let changes: AsyncStream<ProtoFile>

    init() {
        var cont: AsyncStream<ProtoFile>.Continuation!
        self.changes = AsyncStream { cont = $0 }
        self._continuation = cont
    }

    var startWatchingCalls: [ProtoFile] {
        storage.withLock { $0.startWatchingCalls }
    }

    var stopWatchingCalls: [ProtoFile] {
        storage.withLock { $0.stopWatchingCalls }
    }

    func startWatching(_ protoFile: ProtoFile) {
        storage.withLock { $0.startWatchingCalls.append(protoFile) }
    }

    func stopWatching(_ protoFile: ProtoFile) {
        storage.withLock { $0.stopWatchingCalls.append(protoFile) }
    }

    func emit(_ protoFile: ProtoFile) {
        _continuation.yield(protoFile)
    }
}
