import Foundation
import os
@testable import TrueRPCMini

/// Spy for AssignContractColorSlotsUseCaseProtocol that records calls and returns `stubbedSlots`
/// or, when it is nil, a slot per path in order.
final class MockAssignContractColorSlotsUseCase: AssignContractColorSlotsUseCaseProtocol, Sendable {
    struct Call: Equatable, Sendable {
        let protoFilePaths: [URL]
        let currentSlots: [URL: Int]
    }

    private struct Storage: Sendable {
        var calls: [Call] = []
        var stubbedSlots: [URL: Int]?
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    var calls: [Call] {
        storage.withLock { $0.calls }
    }

    var stubbedSlots: [URL: Int]? {
        get { storage.withLock { $0.stubbedSlots } }
        set { storage.withLock { $0.stubbedSlots = newValue } }
    }

    func execute(protoFilePaths: [URL], currentSlots: [URL: Int]) -> [URL: Int] {
        storage.withLock { storage in
            storage.calls.append(Call(protoFilePaths: protoFilePaths, currentSlots: currentSlots))
            if let stubbedSlots = storage.stubbedSlots {
                return stubbedSlots
            }
            return Dictionary(
                protoFilePaths.enumerated().map { ($1, $0) },
                uniquingKeysWith: { first, _ in first })
        }
    }
}
