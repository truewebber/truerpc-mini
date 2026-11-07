import XCTest
@testable import TrueRPCMini

final class ContractIconTests: XCTestCase {
    func test_palette_hasOneColorForEveryContractColorSlot() {
        XCTAssertEqual(ContractColorPalette.count, 8)
        XCTAssertEqual(ContractColors.swatches.count, ContractColorPalette.count)
        XCTAssertEqual(ContractColors.palette.count, ContractColorPalette.count)
    }

    func test_swatches_eachNextColorIsOppositeThePrevious() {
        for stops in [ContractColors.swatches.map(\.light), ContractColors.swatches.map(\.dark)] {
            for index in stops.indices.dropFirst() {
                let distance = Self.labDistance(stops[index - 1], stops[index])
                XCTAssertGreaterThan(
                    distance,
                    70,
                    "slots \(index - 1) and \(index) are \(distance) apart")
            }
        }
    }

    func test_swatches_stayDistinguishableInLightAndDark() {
        for stops in [ContractColors.swatches.map(\.light), ContractColors.swatches.map(\.dark)] {
            for index in stops.indices {
                for other in stops.indices where other > index {
                    let distance = Self.labDistance(stops[index], stops[other])
                    XCTAssertGreaterThan(
                        distance,
                        24,
                        "slots \(index) and \(other) are \(distance) apart")
                }
            }
        }
    }

    /// CIE76 distance. Below about 25 two small swatches start to look like the same color.
    private static func labDistance(_ lhs: ContractColorStop, _ rhs: ContractColorStop) -> Double {
        let left = lab(lhs)
        let right = lab(rhs)
        let dl = left.l - right.l
        let da = left.a - right.a
        let db = left.b - right.b
        return (dl * dl + da * da + db * db).squareRoot()
    }

    private static func lab(_ stop: ContractColorStop) -> (l: Double, a: Double, b: Double) {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let red = linear(stop.red)
        let green = linear(stop.green)
        let blue = linear(stop.blue)
        let x = red * 0.4124564 + green * 0.3575761 + blue * 0.1804375
        let y = red * 0.2126729 + green * 0.7151522 + blue * 0.0721750
        let z = red * 0.0193339 + green * 0.1191920 + blue * 0.9503041
        func pivot(_ channel: Double, _ white: Double) -> Double {
            let ratio = channel / white
            return ratio > 0.008856 ? pow(ratio, 1.0 / 3.0) : 7.787 * ratio + 16.0 / 116.0
        }
        let fx = pivot(x, 0.95047)
        let fy = pivot(y, 1)
        let fz = pivot(z, 1.08883)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }
}
