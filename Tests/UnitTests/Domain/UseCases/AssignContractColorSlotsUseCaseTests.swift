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
}
