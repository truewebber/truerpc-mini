import Foundation

/// Persistable snapshot of an EditorTab for restoration across app restarts
public struct EditorTabState: Identifiable, Equatable, Codable {
    public let id: UUID
    public let protoFilePath: String
    public let serviceName: String
    public let methodName: String

    public init(
        id: UUID = UUID(),
        protoFilePath: String,
        serviceName: String,
        methodName: String)
    {
        self.id = id
        self.protoFilePath = protoFilePath
        self.serviceName = serviceName
        self.methodName = methodName
    }

    public init(editorTab: EditorTab) {
        self.id = editorTab.id
        self.protoFilePath = editorTab.protoFile.path.path
        self.serviceName = editorTab.serviceName
        self.methodName = editorTab.methodName
    }
}
