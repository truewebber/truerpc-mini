import Foundation

/// Chooses the suggestion panel's side and frame.
///
/// The panel sticks to the caret. It opens under the line when that side has room, otherwise above it.
/// A list that does not fit shrinks to the free room. The frame stays inside `limits`, which is the
/// window cropped to the visible screen, so the panel does not slide onto the Dock or off the display.
public enum PlaceAutocompletePopover {
    public static let gap: Double = 4
    public static let minimumHeight: Double = 36

    public static func place(
        caret: EditorRect,
        visibleEditor: EditorRect,
        limits: EditorRect,
        contentSize: EditorSize)
        -> AutocompletePopoverPlacement?
    {
        guard visibleEditor.contains(x: caret.midX, y: caret.midY) else { return nil }
        guard limits.width > 0, limits.height > 0 else { return nil }

        let width = min(max(contentSize.width, 0), limits.width)
        guard width > 0 else { return nil }

        let roomBelow = limits.maxY - caret.maxY - gap
        let roomAbove = caret.minY - limits.minY - gap
        guard let choice = side(
            preferredHeight: contentSize.height,
            roomBelow: roomBelow,
            roomAbove: roomAbove)
        else { return nil }

        let frame = EditorRect(
            x: horizontalOrigin(caretMidX: caret.midX, width: width, limits: limits),
            y: choice.side == .below ? caret.maxY + gap : caret.minY - gap - choice.height,
            width: width,
            height: choice.height)
        return AutocompletePopoverPlacement(side: choice.side, frame: frame)
    }

    private static func side(
        preferredHeight: Double,
        roomBelow: Double,
        roomAbove: Double)
        -> (side: AutocompletePopoverSide, height: Double)?
    {
        if roomBelow >= preferredHeight {
            return (.below, preferredHeight)
        }
        if roomAbove >= preferredHeight {
            return (.above, preferredHeight)
        }
        if roomBelow >= roomAbove, roomBelow >= minimumHeight {
            return (.below, roomBelow)
        }
        if roomAbove >= minimumHeight {
            return (.above, roomAbove)
        }
        return nil
    }

    private static func horizontalOrigin(caretMidX: Double, width: Double, limits: EditorRect) -> Double {
        let minimum = limits.minX
        let maximum = limits.maxX - width
        guard maximum >= minimum else { return minimum }

        return min(max(caretMidX - width / 2, minimum), maximum)
    }
}
