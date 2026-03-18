import XCTest
@testable import TrueRPCMini

final class ServerEnvironmentTests: XCTestCase {
    // MARK: - TLS field

    func test_init_defaultTLSConfiguration_isPlaintext() {
        let env = ServerEnvironment(name: "Local", host: "localhost", port: 50051)

        XCTAssertEqual(env.tlsConfiguration, TLSConfiguration.defaults)
    }

    func test_init_customTLSConfiguration_isStored() {
        let tls = TLSConfiguration(isTLSEnabled: true, allowInsecure: false)
        let env = ServerEnvironment(name: "Secure", host: "api.example.com", port: 443, tlsConfiguration: tls)

        XCTAssertEqual(env.tlsConfiguration, tls)
    }

    // MARK: - Legacy JSON decoding (backward compatibility)

    func test_serverEnvironment_decodesLegacyJSON_withDefaultTLS() throws {
        let legacyJSON = """
        {
            "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
            "name": "Legacy Env",
            "host": "old-server.example.com",
            "port": 9090
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ServerEnvironment.self, from: legacyJSON)

        XCTAssertEqual(decoded.name, "Legacy Env")
        XCTAssertEqual(decoded.host, "old-server.example.com")
        XCTAssertEqual(decoded.port, 9090)
        XCTAssertEqual(decoded.tlsConfiguration, TLSConfiguration.defaults)
    }

    // MARK: - Codable round-trip

    func test_serverEnvironment_encodesAndDecodes_tlsConfiguration() throws {
        let tls = TLSConfiguration(
            isTLSEnabled: true,
            allowInsecure: true,
            sniOverride: "override.example.com")
        let original = ServerEnvironment(
            id: UUID(),
            name: "TLS Env",
            host: "secure.example.com",
            port: 443,
            tlsConfiguration: tls)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerEnvironment.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.tlsConfiguration, tls)
    }

    // MARK: - Equatable

    func test_serverEnvironment_equality_respectsTLSConfiguration() {
        let id = UUID()
        let tlsA = TLSConfiguration(isTLSEnabled: false, allowInsecure: false)
        let tlsB = TLSConfiguration(isTLSEnabled: true, allowInsecure: false)

        let envA = ServerEnvironment(id: id, name: "Env", host: "host", port: 80, tlsConfiguration: tlsA)
        let envB = ServerEnvironment(id: id, name: "Env", host: "host", port: 80, tlsConfiguration: tlsB)

        XCTAssertNotEqual(envA, envB)
    }

    func test_serverEnvironment_equality_sameTLS_returnsTrue() {
        let id = UUID()
        let tls = TLSConfiguration(isTLSEnabled: true, allowInsecure: false)

        let envA = ServerEnvironment(id: id, name: "Env", host: "host", port: 80, tlsConfiguration: tls)
        let envB = ServerEnvironment(id: id, name: "Env", host: "host", port: 80, tlsConfiguration: tls)

        XCTAssertEqual(envA, envB)
    }
}
