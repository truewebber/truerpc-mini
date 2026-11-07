import AppKit

/// Copies a string onto the general pasteboard.
public struct PasteboardClipboard: ClipboardProtocol {
    public init() {}

    public func copyString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
