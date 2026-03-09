import Foundation

/// Represents a named server endpoint configuration
public struct ServerEnvironment: Equatable, Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int

    /// Formatted connection URL: "host:port"
    public var url: String {
        "\(host):\(port)"
    }

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int)
    {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
    }
}
