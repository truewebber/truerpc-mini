import Foundation

/// Represents a named server endpoint configuration
public struct ServerEnvironment: Equatable, Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var tlsConfiguration: TLSConfiguration

    /// Formatted connection URL: "host:port"
    public var url: String {
        "\(host):\(port)"
    }

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int,
        tlsConfiguration: TLSConfiguration = .defaults)
    {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.tlsConfiguration = tlsConfiguration
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, name, host, port, tlsConfiguration
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.host = try container.decode(String.self, forKey: .host)
        self.port = try container.decode(Int.self, forKey: .port)
        self.tlsConfiguration = try container
            .decodeIfPresent(TLSConfiguration.self, forKey: .tlsConfiguration) ?? .defaults
    }
}
