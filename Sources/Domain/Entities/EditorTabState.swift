import Foundation

/// Persistable snapshot of an EditorTab for restoration across app restarts
public struct EditorTabState: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let protoFilePath: String
    public let serviceName: String
    public let methodName: String
    public let selectedEnvironmentId: UUID?
    public let customUrl: String?
    /// Per-tab TLS override used in Custom URL mode. Nil means TLSConfiguration.defaults (plaintext).
    public let adHocTLSConfiguration: TLSConfiguration?

    private enum CodingKeys: String, CodingKey {
        case id
        case protoFilePath
        case serviceName
        case methodName
        case selectedEnvironmentId
        case customUrl
        case adHocTLSConfiguration
    }

    public init(
        id: UUID = UUID(),
        protoFilePath: String,
        serviceName: String,
        methodName: String,
        selectedEnvironmentId: UUID? = nil,
        customUrl: String? = nil,
        adHocTLSConfiguration: TLSConfiguration? = nil)
    {
        self.id = id
        self.protoFilePath = protoFilePath
        self.serviceName = serviceName
        self.methodName = methodName
        self.selectedEnvironmentId = selectedEnvironmentId
        self.customUrl = customUrl
        self.adHocTLSConfiguration = adHocTLSConfiguration
    }

    public init(editorTab: EditorTab, tabEnvironment: ServerEnvironment? = nil, customUrl: String? = nil) {
        self.id = editorTab.id
        self.protoFilePath = editorTab.protoFile.path.path
        self.serviceName = editorTab.serviceName
        self.methodName = editorTab.methodName
        self.selectedEnvironmentId = tabEnvironment?.id
        self.customUrl = tabEnvironment == nil ? (customUrl?.isEmpty == false ? customUrl : nil) : nil
        self.adHocTLSConfiguration = nil
    }
}
