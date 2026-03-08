import Foundation
@testable import TrueRPCMini

class MockProtoFileWatcher: ProtoFileWatcherProtocol {
    var startWatchingCalls: [ProtoFile] = []
    var stopWatchingCalls: [ProtoFile] = []

    let changes: AsyncStream<ProtoFile>
    private var continuation: AsyncStream<ProtoFile>.Continuation!

    init() {
        var cont: AsyncStream<ProtoFile>.Continuation!
        changes = AsyncStream { cont = $0 }
        continuation = cont
    }

    func startWatching(_ protoFile: ProtoFile) {
        startWatchingCalls.append(protoFile)
    }

    func stopWatching(_ protoFile: ProtoFile) {
        stopWatchingCalls.append(protoFile)
    }

    func emit(_ protoFile: ProtoFile) {
        continuation.yield(protoFile)
    }
}
