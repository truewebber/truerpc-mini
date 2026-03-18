import Foundation
import os
@testable import TrueRPCMini

final class MockDeleteEnvironmentUseCase: DeleteEnvironmentUseCaseProtocol, Sendable {
    private struct Storage {
        var deletedIds: [UUID] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    var deletedIds: [UUID] {
        storage.withLock { $0.deletedIds }
    }

    func execute(id: UUID) {
        storage.withLock { $0.deletedIds.append(id) }
    }
}
