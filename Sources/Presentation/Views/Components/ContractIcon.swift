import SwiftUI

/// Document symbol tinted with the color of a proto contract, so the sidebar row, the editor tabs, and the tab
/// switcher show one contract alike. Always shown next to the contract or method name, never alone.
struct ContractIcon: View {
    /// Slot from `AssignContractColorSlotsUseCase`; `nil` for a contract that is no longer loaded.
    let colorSlot: Int?

    /// Clearly distinct hues that do not carry status meaning elsewhere in the app (green, red, orange, and
    /// yellow do). A seventh contract repeats a color rather than getting a near-identical one.
    static let palette: [Color] = [.blue, .pink, .teal, .purple, .brown, .indigo]

    var body: some View {
        Image(systemName: "doc.text.fill")
            .foregroundStyle(style)
            .accessibilityHidden(true)
    }

    private var style: AnyShapeStyle {
        guard let colorSlot else { return AnyShapeStyle(.secondary) }

        return AnyShapeStyle(Self.palette[colorSlot % Self.palette.count])
    }
}

#if DEBUG
    #Preview("Palette", traits: .sizeThatFitsLayout) {
        HStack {
            ForEach(0 ..< ContractIcon.palette.count, id: \.self) { slot in
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
            ForEach(0 ..< ContractIcon.palette.count, id: \.self) { slot in
                ContractIcon(colorSlot: slot)
            }
        }
        .padding()
        .background(.background)
        .preferredColorScheme(.dark)
    }
#endif
