import Foundation

/// Assigns stable color slots to loaded proto contracts.
public final class AssignContractColorSlotsUseCase: AssignContractColorSlotsUseCaseProtocol, Sendable {
    public init() {}

    public func execute(protoFilePaths: [URL], currentSlots: [URL: Int]) -> [URL: Int] {
        var slots: [URL: Int] = [:]
        for path in protoFilePaths {
            if let slot = currentSlots[path] {
                slots[path] = slot
            }
        }

        var usedSlots = Set(slots.values)
        var candidate = 0
        for path in protoFilePaths where slots[path] == nil {
            while usedSlots.contains(candidate) {
                candidate += 1
            }
            slots[path] = candidate
            usedSlots.insert(candidate)
        }
        return slots
    }
}
