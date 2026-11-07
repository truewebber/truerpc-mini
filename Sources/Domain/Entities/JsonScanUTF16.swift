import Foundation

/// UTF-16 code units for the ASCII characters that structure JSON.
public enum JsonScanUTF16 {
    public static let quote: UInt16 = 0x22
    public static let backslash: UInt16 = 0x5C
    public static let bracketOpen: UInt16 = 0x5B
    public static let bracketClose: UInt16 = 0x5D
    public static let braceOpen: UInt16 = 0x7B
    public static let braceClose: UInt16 = 0x7D
    public static let space: UInt16 = 0x20
    public static let lf: UInt16 = 0x0A
    public static let cr: UInt16 = 0x0D
    public static let tab: UInt16 = 0x09
    public static let comma: UInt16 = 0x2C
    public static let colon: UInt16 = 0x3A
}
