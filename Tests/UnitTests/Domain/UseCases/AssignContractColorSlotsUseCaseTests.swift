import XCTest
@testable import TrueRPCMini

final class AssignContractColorSlotsUseCaseTests: XCTestCase {
    private var sut: AssignContractColorSlotsUseCase!

    private let users = URL(fileURLWithPath: "/protos/users.proto")
    private let billing = URL(fileURLWithPath: "/protos/billing.proto")
    private let orders = URL(fileURLWithPath: "/protos/orders.proto")

    override func setUp() {
        super.setUp()
        sut = AssignContractColorSlotsUseCase()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_execute_withoutCurrentSlots_assignsSlotsInContractOrder() {
        let slots = sut.execute(protoFilePaths: [users, billing, orders], currentSlots: [:])

        XCTAssertEqual(slots, [users: 0, billing: 1, orders: 2])
    }

    func test_execute_keepsSlotsOfContractsThatStayLoaded() {
        let slots = sut.execute(protoFilePaths: [billing, users], currentSlots: [users: 0, billing: 1])

        XCTAssertEqual(slots, [users: 0, billing: 1])
    }

    func test_execute_newContractTakesLowestFreeSlot() {
        let slots = sut.execute(protoFilePaths: [billing, orders], currentSlots: [users: 0, billing: 1])

        XCTAssertEqual(slots, [billing: 1, orders: 0])
    }

    func test_execute_dropsContractsThatAreNoLongerLoaded() {
        let slots = sut.execute(protoFilePaths: [billing], currentSlots: [users: 0, billing: 1])

        XCTAssertEqual(slots, [billing: 1])
    }

    func test_execute_withDuplicatePath_assignsOneSlot() {
        let slots = sut.execute(protoFilePaths: [users, users, billing], currentSlots: [:])

        XCTAssertEqual(slots, [users: 0, billing: 1])
    }

    func test_execute_whenContractsExceedPalette_repeatsColorsFromTheFirst() {
        let paths = contractPaths(count: ContractColorPalette.count + 1)

        let slots = sut.execute(protoFilePaths: paths, currentSlots: [:])

        XCTAssertEqual(slots[paths[0]], 0)
        XCTAssertEqual(slots[paths[ContractColorPalette.count]], ContractColorPalette.count)
        XCTAssertEqual(colorIndex(slots[paths[0]]), colorIndex(slots[paths[ContractColorPalette.count]]))
    }

    func test_execute_whenOnlyContractsSharingAColorRemain_reassignsTheLaterOne() {
        let paths = contractPaths(count: ContractColorPalette.count + 1)
        let assigned = sut.execute(protoFilePaths: paths, currentSlots: [:])
        let first = paths[0]
        let extra = paths[ContractColorPalette.count]

        let slots = sut.execute(protoFilePaths: [first, extra], currentSlots: assigned)

        XCTAssertEqual(slots[first], 0)
        XCTAssertEqual(slots[extra], 1)
        XCTAssertNotEqual(colorIndex(slots[first]), colorIndex(slots[extra]))
    }

    func test_execute_whenThreeContractsShareOneColor_keepsTheEarliestSlot() {
        let earliest = contractPaths(count: 1)[0]
        let later = URL(fileURLWithPath: "/protos/later.proto")
        let latest = URL(fileURLWithPath: "/protos/latest.proto")

        let slots = sut.execute(
            protoFilePaths: [latest, earliest, later],
            currentSlots: [
                earliest: 0,
                later: ContractColorPalette.count,
                latest: ContractColorPalette.count * 2,
            ])

        XCTAssertEqual(slots[earliest], 0)
        XCTAssertEqual(slots[later], 1)
        XCTAssertEqual(slots[latest], 2)
    }

    func test_execute_whenWrappedSlotIsTheOnlyOneOfItsColor_keepsThatSlot() {
        let wrapped = URL(fileURLWithPath: "/protos/wrapped.proto")

        let slots = sut.execute(
            protoFilePaths: [wrapped],
            currentSlots: [users: 0, wrapped: ContractColorPalette.count])

        XCTAssertEqual(slots, [wrapped: ContractColorPalette.count])
    }

    func test_execute_whenRemainingWrappedSlotsUseDifferentColors_keepsThoseSlots() {
        let paths = contractPaths(count: ContractColorPalette.count + 2)
        let assigned = sut.execute(protoFilePaths: paths, currentSlots: [:])
        let firstOverflow = paths[ContractColorPalette.count]
        let secondOverflow = paths[ContractColorPalette.count + 1]

        let slots = sut.execute(
            protoFilePaths: [secondOverflow, firstOverflow],
            currentSlots: assigned)

        XCTAssertEqual(slots[firstOverflow], assigned[firstOverflow])
        XCTAssertEqual(slots[secondOverflow], assigned[secondOverflow])
        XCTAssertNotEqual(colorIndex(slots[firstOverflow]), colorIndex(slots[secondOverflow]))
    }

    private func contractPaths(count: Int) -> [URL] {
        (0 ..< count).map { URL(fileURLWithPath: "/protos/contract-\($0).proto") }
    }

    private func colorIndex(_ slot: Int?) -> Int {
        (slot ?? -1) % ContractColorPalette.count
    }
}
