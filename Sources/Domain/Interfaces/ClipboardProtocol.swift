import Foundation

/// Copies text for the user. The view model does not talk to the pasteboard itself.
public protocol ClipboardProtocol: Sendable {
    func copyString(_ string: String)
}
