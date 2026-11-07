import AppKit
import SwiftUI

/// sRGB channels of one prepared contract color, from 0 to 1.
struct ContractColorStop: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ hex: UInt32) {
        self.red = Double((hex >> 16) & 0xFF) / 255
        self.green = Double((hex >> 8) & 0xFF) / 255
        self.blue = Double(hex & 0xFF) / 255
    }
}

/// A contract color in light and dark appearances. Most swatches use one color for both; indigo and brown
/// are lightened in the dark appearance so they stay visible without turning into a different hue.
struct ContractColorSwatch: Equatable {
    let light: ContractColorStop
    let dark: ContractColorStop

    var color: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let useDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let stop = useDark ? dark : light
            return NSColor(srgbRed: stop.red, green: stop.green, blue: stop.blue, alpha: 1)
        })
    }
}

/// Prepared categorical colors, in the order a new contract receives them. Each entry is an opposing color
/// to the one before it, so the sequence jumps across the wheel instead of walking around it. Red, orange,
/// yellow, and green stay reserved for status. Contains `ContractColorPalette.count` colors: a further
/// contract repeats one.
///
/// Order: indigo, brown, cyan, wine, olive, purple, teal, rose.
enum ContractColors {
    static let swatches: [ContractColorSwatch] = [
        ContractColorSwatch(light: ContractColorStop(0x332288), dark: ContractColorStop(0x4E3CC4)),
        ContractColorSwatch(light: ContractColorStop(0x8F5528), dark: ContractColorStop(0xA66B38)),
        ContractColorSwatch(light: ContractColorStop(0x88CCEE), dark: ContractColorStop(0x88CCEE)),
        ContractColorSwatch(light: ContractColorStop(0x882255), dark: ContractColorStop(0x882255)),
        ContractColorSwatch(light: ContractColorStop(0x999933), dark: ContractColorStop(0x999933)),
        ContractColorSwatch(light: ContractColorStop(0xAA4499), dark: ContractColorStop(0xAA4499)),
        ContractColorSwatch(light: ContractColorStop(0x44AA99), dark: ContractColorStop(0x44AA99)),
        ContractColorSwatch(light: ContractColorStop(0xCC6677), dark: ContractColorStop(0xCC6677)),
    ]

    static let palette: [Color] = swatches.map(\.color)
}

/// Document symbol tinted with the color of a proto contract. The row it marks is the contract file: the
/// sidebar and the tab switcher section. Always shown next to the file name, never alone.
struct ContractIcon: View {
    /// Slot from `AssignContractColorSlotsUseCase`; `nil` for a contract that is no longer loaded.
    let colorSlot: Int?

    var body: some View {
        Image(systemName: "doc.text.fill")
            .foregroundStyle(Self.color(forSlot: colorSlot))
            .accessibilityHidden(true)
    }

    static func color(forSlot slot: Int?) -> Color {
        guard let slot else { return .secondary }

        let remainder = slot % ContractColors.palette.count
        let index = remainder >= 0 ? remainder : remainder + ContractColors.palette.count
        return ContractColors.palette[index]
    }
}

/// Contract color alone, for a row that is a method rather than the contract file. The tab uses it in place of
/// `ContractIcon`: every tab would otherwise repeat the same document glyph.
struct ContractColorMark: View {
    let colorSlot: Int?

    private static let diameter: CGFloat = 8

    var body: some View {
        Circle()
            .fill(ContractIcon.color(forSlot: colorSlot))
            .frame(width: Self.diameter, height: Self.diameter)
            .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview("Palette", traits: .sizeThatFitsLayout) {
        HStack {
            ForEach(0 ..< ContractColors.palette.count, id: \.self) { slot in
                ContractIcon(colorSlot: slot)
            }
        }
        .padding()
    }

    #Preview("Unassigned", traits: .sizeThatFitsLayout) {
        Label {
            Text("removed.proto")
        } icon: {
            ContractIcon(colorSlot: nil)
        }
        .padding()
    }

    #Preview("Dark", traits: .sizeThatFitsLayout) {
        HStack {
            ForEach(0 ..< ContractColors.palette.count, id: \.self) { slot in
                ContractIcon(colorSlot: slot)
            }
        }
        .padding()
        .background(.background)
        .preferredColorScheme(.dark)
    }

    #Preview("Color Mark", traits: .sizeThatFitsLayout) {
        HStack {
            ForEach(0 ..< ContractColors.palette.count, id: \.self) { slot in
                ContractColorMark(colorSlot: slot)
            }
            ContractColorMark(colorSlot: nil)
        }
        .padding()
    }

    #Preview("Color Mark Dark", traits: .sizeThatFitsLayout) {
        HStack {
            ForEach(0 ..< ContractColors.palette.count, id: \.self) { slot in
                ContractColorMark(colorSlot: slot)
            }
        }
        .padding()
        .background(.background)
        .preferredColorScheme(.dark)
    }
#endif
