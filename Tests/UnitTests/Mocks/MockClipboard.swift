import Foundation
import os
@testable import TrueRPCMini

final class MockClipboard: ClipboardProtocol, Sendable {
    private struct State: Sendable {
        var copied: String?
    }

    private let storage = OSAllocatedUnfairLock(initialState: State())

    func copyString(_ string: String) {
        storage.withLock { $0.copied = string }
    }

    var copied: String? {
        storage.withLock { $0.copied }
    }
}
