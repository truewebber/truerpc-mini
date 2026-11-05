import Foundation

/// Gives every loaded proto contract a color slot so the contract looks the same in every view.
public protocol AssignContractColorSlotsUseCaseProtocol: Sendable {
    /// - Parameters:
    ///   - protoFilePaths: Loaded contracts in sidebar order.
    ///   - currentSlots: Slots assigned before this change.
    /// - Returns: A slot for every loaded contract. A contract keeps its slot while it stays loaded;
    ///   a new contract takes the lowest free slot. Slots start at zero.
    func execute(protoFilePaths: [URL], currentSlots: [URL: Int]) -> [URL: Int]
}
