import Foundation

/// A rectangle in a top-left space whose y axis grows downward.
/// The caret, the visible editor, the screen, and the suggestion panel share this space.
public struct EditorRect: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var minX: Double {
        x
    }

    public var minY: Double {
        y
    }

    public var maxX: Double {
        x + width
    }

    public var maxY: Double {
        y + height
    }

    public var midX: Double {
        x + width / 2
    }

    public var midY: Double {
        y + height / 2
    }

    public func contains(_ other: EditorRect) -> Bool {
        other.minX >= minX && other.maxX <= maxX && other.minY >= minY && other.maxY <= maxY
    }

    public func intersects(_ other: EditorRect) -> Bool {
        minX < other.maxX && maxX > other.minX && minY < other.maxY && maxY > other.minY
    }

    func contains(x pointX: Double, y pointY: Double) -> Bool {
        pointX >= minX && pointX < maxX && pointY >= minY && pointY < maxY
    }
}

public struct EditorSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Which side of the caret the suggestion panel occupies.
public enum AutocompletePopoverSide: Equatable, Sendable {
    /// The panel sits under the line. Its arrow points up at the caret.
    case below
    /// The panel sits above the line. Its arrow points down at the caret.
    case above
}

/// Where the suggestion panel is drawn, or why it stays closed.
public struct AutocompletePopoverPlacement: Equatable, Sendable {
    public var side: AutocompletePopoverSide
    public var frame: EditorRect

    public init(side: AutocompletePopoverSide, frame: EditorRect) {
        self.side = side
        self.frame = frame
    }
}
