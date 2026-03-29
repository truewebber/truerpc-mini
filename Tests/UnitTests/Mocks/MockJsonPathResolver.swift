import OSLog
@testable import TrueRPCMini

final class MockJsonPathResolver: JsonPathResolverProtocol, Sendable {
    private struct Storage: @unchecked Sendable {
        // @unchecked Sendable: all mutations serialised on the OSAllocatedUnfairLock below.
        var resolveResult: AutocompleteContext = .init(resolvedPath: [], mode: .key)
        var collectKeysResult: Set<String> = []
        var resolveCallCount: Int = 0
        var lastResolveJson: String?
        var lastResolveOffset: Int = 0
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    func stubResolve(_ context: AutocompleteContext) {
        storage.withLock { $0.resolveResult = context }
    }

    func stubCollectKeys(_ keys: Set<String>) {
        storage.withLock { $0.collectKeysResult = keys }
    }

    var resolveCallCount: Int {
        storage.withLock { $0.resolveCallCount }
    }

    var lastResolveJson: String? {
        storage.withLock { $0.lastResolveJson }
    }

    var lastResolveOffset: Int {
        storage.withLock { $0.lastResolveOffset }
    }

    func resolve(json: String, cursorOffset: Int) -> AutocompleteContext {
        storage.withLock {
            $0.resolveCallCount += 1
            $0.lastResolveJson = json
            $0.lastResolveOffset = cursorOffset
            return $0.resolveResult
        }
    }

    func collectKeysAfterCursor(json _: String, cursorOffset _: Int) -> Set<String> {
        storage.withLock { $0.collectKeysResult }
    }
}
