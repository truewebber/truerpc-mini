import Foundation
import os
@testable import TrueRPCMini

final class MockSaveEnvironmentUseCase: SaveEnvironmentUseCaseProtocol, Sendable {
    private struct Storage {
        var savedEnvironments: [ServerEnvironment] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    var savedEnvironments: [ServerEnvironment] {
        storage.withLock { $0.savedEnvironments }
    }

    func execute(_ environment: ServerEnvironment) {
        storage.withLock { $0.savedEnvironments.append(environment) }
    }
}
