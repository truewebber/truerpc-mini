import Foundation

/// Gives every loaded proto contract a color slot so the contract looks the same in every view.
public protocol AssignContractColorSlotsUseCaseProtocol: Sendable {
    /// - Parameters:
    ///   - protoFilePaths: Loaded contracts in sidebar order.
    ///   - currentSlots: Slots assigned before this change.
    /// - Returns: A slot for every loaded contract. The visible color is `slot % ContractColorPalette.count`.
    ///   A contract keeps its slot while no other loaded contract uses that color. When several do, the
    ///   lowest slot keeps it and the others take the lowest free colors. A new contract does the same,
    ///   reusing the least-used colors once every color is taken. Slots start at zero.
    func execute(protoFilePaths: [URL], currentSlots: [URL: Int]) -> [URL: Int]
}
