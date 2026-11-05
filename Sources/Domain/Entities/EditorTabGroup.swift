import Foundation

/// Open editor tabs that belong to one proto contract, in tab order.
public struct EditorTabGroup: Equatable, Identifiable, Sendable {
    public var id: URL {
        protoFilePath
    }

    public let protoFilePath: URL
    public let protoFileName: String
    public let tabs: [EditorTab]

    public init(protoFilePath: URL, protoFileName: String, tabs: [EditorTab]) {
        self.protoFilePath = protoFilePath
        self.protoFileName = protoFileName
        self.tabs = tabs
    }
}
