import Foundation

/// Persistable snapshot of an EditorTab for restoration across app restarts
public struct EditorTabState: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let protoFilePath: String
    public let serviceName: String
    public let methodName: String
    public let selectedEnvironmentId: UUID?
    public let customUrl: String?

    public init(
        id: UUID = UUID(),
        protoFilePath: String,
        serviceName: String,
        methodName: String,
        selectedEnvironmentId: UUID? = nil,
        customUrl: String? = nil)
    {
        self.id = id
        self.protoFilePath = protoFilePath
        self.serviceName = serviceName
        self.methodName = methodName
        self.selectedEnvironmentId = selectedEnvironmentId
        self.customUrl = customUrl
    }

    public init(editorTab: EditorTab, tabEnvironment: ServerEnvironment? = nil, customUrl: String? = nil) {
        self.id = editorTab.id
        self.protoFilePath = editorTab.protoFile.path.path
        self.serviceName = editorTab.serviceName
        self.methodName = editorTab.methodName
        self.selectedEnvironmentId = tabEnvironment?.id
        self.customUrl = tabEnvironment == nil ? (customUrl?.isEmpty == false ? customUrl : nil) : nil
    }
}
