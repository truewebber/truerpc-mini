import Foundation
import os
@testable import TrueRPCMini

final class MockLoadEnvironmentsUseCase: LoadEnvironmentsUseCaseProtocol, Sendable {
    private struct Storage {
        var executeCallCount = 0
        var stubbedResult: [ServerEnvironment] = []
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    var executeCallCount: Int {
        get { storage.withLock { $0.executeCallCount } }
        set { storage.withLock { $0.executeCallCount = newValue } }
    }

    var stubbedResult: [ServerEnvironment] {
        get { storage.withLock { $0.stubbedResult } }
        set { storage.withLock { $0.stubbedResult = newValue } }
    }

    func execute() -> [ServerEnvironment] {
        storage.withLock { st -> [ServerEnvironment] in
            st.executeCallCount += 1
            return st.stubbedResult
        }
    }
}
