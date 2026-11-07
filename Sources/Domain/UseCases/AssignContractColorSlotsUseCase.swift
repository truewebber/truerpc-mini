import Foundation

/// Assigns stable color slots to loaded proto contracts.
///
/// A contract keeps its slot while its color is unique among the contracts that stay loaded. When several
/// share a color, the lowest slot keeps it and the others move to free colors.
public final class AssignContractColorSlotsUseCase: AssignContractColorSlotsUseCaseProtocol, Sendable {
    public init() {}

    public func execute(protoFilePaths: [URL], currentSlots: [URL: Int]) -> [URL: Int] {
        let paths = uniquePaths(in: protoFilePaths)
        let retained = retainedSlots(among: paths, currentSlots: currentSlots)
        let kept = slotsKeepingTheirColor(retained)
        let displaced = pathsLosingTheirColor(retained, kept: kept)
        let newcomers = paths.filter { currentSlots[$0] == nil }
        return assigningFreeColors(kept: kept, displaced: displaced, newcomers: newcomers)
    }

    private func uniquePaths(in protoFilePaths: [URL]) -> [URL] {
        var seen = Set<URL>()
        return protoFilePaths.filter { seen.insert($0).inserted }
    }

    private func retainedSlots(
        among paths: [URL],
        currentSlots: [URL: Int])
        -> [Int: [(path: URL, slot: Int)]]
    {
        let retained = paths.compactMap { path -> (path: URL, slot: Int)? in
            guard let slot = currentSlots[path] else { return nil }

            return (path, slot)
        }
        return Dictionary(grouping: retained) { colorIndex(of: $0.slot) }
    }

    private func slotsKeepingTheirColor(_ retained: [Int: [(path: URL, slot: Int)]]) -> [URL: Int] {
        var kept: [URL: Int] = [:]
        for group in retained.values {
            guard let earliest = group.min(by: isEarlierSlot) else { continue }

            kept[earliest.path] = earliest.slot
        }
        return kept
    }

    private func pathsLosingTheirColor(
        _ retained: [Int: [(path: URL, slot: Int)]],
        kept: [URL: Int])
        -> [URL]
    {
        retained.values
            .flatMap(\.self)
            .filter { kept[$0.path] != $0.slot }
            .sorted(by: isEarlierSlot)
            .map(\.path)
    }

    private func assigningFreeColors(
        kept: [URL: Int],
        displaced: [URL],
        newcomers: [URL])
        -> [URL: Int]
    {
        var result = kept
        var usedSlots = Set(kept.values)
        var colorCounts = [Int: Int]()
        for slot in usedSlots {
            colorCounts[colorIndex(of: slot), default: 0] += 1
        }

        for path in displaced + newcomers {
            let slot = lowestFreeSlot(usedSlots: usedSlots, colorCounts: colorCounts)
            result[path] = slot
            usedSlots.insert(slot)
            colorCounts[colorIndex(of: slot), default: 0] += 1
        }
        return result
    }

    /// Lowest color index with the fewest contracts, then the lowest slot of that color.
    private func lowestFreeSlot(usedSlots: Set<Int>, colorCounts: [Int: Int]) -> Int {
        let color = (0 ..< ContractColorPalette.count).min { lhs, rhs in
            let left = colorCounts[lhs, default: 0]
            let right = colorCounts[rhs, default: 0]
            if left != right {
                return left < right
            }
            return lhs < rhs
        } ?? 0
        var slot = color
        while usedSlots.contains(slot) {
            slot += ContractColorPalette.count
        }
        return slot
    }

    private func isEarlierSlot(
        _ lhs: (path: URL, slot: Int),
        _ rhs: (path: URL, slot: Int))
        -> Bool
    {
        lhs.slot == rhs.slot ? lhs.path.path < rhs.path.path : lhs.slot < rhs.slot
    }

    private func colorIndex(of slot: Int) -> Int {
        let remainder = slot % ContractColorPalette.count
        return remainder >= 0 ? remainder : remainder + ContractColorPalette.count
    }
}
