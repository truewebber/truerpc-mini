import XCTest
@testable import TrueRPCMini

final class TLSConfigurationTests: XCTestCase {
    // MARK: - Defaults

    func test_defaults_isTLSDisabled() {
        XCTAssertFalse(TLSConfiguration.defaults.isTLSEnabled)
    }

    func test_defaults_allowInsecureIsFalse() {
        XCTAssertFalse(TLSConfiguration.defaults.allowInsecure)
    }

    func test_defaults_allOptionalFieldsAreNil() {
        let config = TLSConfiguration.defaults

        XCTAssertNil(config.customCAURL)
        XCTAssertNil(config.clientCertURL)
        XCTAssertNil(config.clientKeyURL)
        XCTAssertNil(config.sniOverride)
    }

    // MARK: - LockIndicatorState

    func test_lockIndicatorState_whenTLSDisabled_returnsPlaintext() {
        let config = TLSConfiguration(isTLSEnabled: false, allowInsecure: false)

        XCTAssertEqual(config.lockIndicatorState, .plaintext)
    }

    func test_lockIndicatorState_whenTLSEnabledAndSecure_returnsSecure() {
        let config = TLSConfiguration(isTLSEnabled: true, allowInsecure: false)

        XCTAssertEqual(config.lockIndicatorState, .secure)
    }

    func test_lockIndicatorState_whenTLSEnabledAndAllowInsecure_returnsInsecure() {
        let config = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)

        XCTAssertEqual(config.lockIndicatorState, .insecure)
    }

    func test_lockIndicatorState_whenTLSEnabledAndCustomCA_returnsInsecure() {
        let config = TLSConfiguration(
            isTLSEnabled: true,
            allowInsecure: false,
            customCAURL: URL(fileURLWithPath: "/certs/ca.pem"))

        XCTAssertEqual(config.lockIndicatorState, .insecure)
    }

    func test_lockIndicatorState_whenTLSEnabledAndMTLS_returnsSecure() {
        let config = TLSConfiguration(
            isTLSEnabled: true,
            allowInsecure: false,
            clientCertURL: URL(fileURLWithPath: "/certs/client.crt"),
            clientKeyURL: URL(fileURLWithPath: "/certs/client.key"))

        XCTAssertEqual(config.lockIndicatorState, .secure)
    }

    func test_lockIndicatorState_whenTLSDisabledWithAllowInsecure_returnsPlaintext() {
        let config = TLSConfiguration(isTLSEnabled: false, allowInsecure: true)

        XCTAssertEqual(config.lockIndicatorState, .plaintext)
    }

    // MARK: - Codable

    func test_codable_roundtrip_withDefaults() throws {
        let original = TLSConfiguration.defaults
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TLSConfiguration.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func test_codable_roundtrip_withAllFields() throws {
        let original = TLSConfiguration(
            isTLSEnabled: true,
            allowInsecure: true,
            customCAURL: URL(fileURLWithPath: "/certs/ca.pem"),
            clientCertURL: URL(fileURLWithPath: "/certs/client.crt"),
            clientKeyURL: URL(fileURLWithPath: "/certs/client.key"),
            sniOverride: "example.com")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(TLSConfiguration.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equatable

    func test_equatable_sameValues_returnsTrue() {
        let a = TLSConfiguration(isTLSEnabled: true, allowInsecure: false, sniOverride: "host.com")
        let b = TLSConfiguration(isTLSEnabled: true, allowInsecure: false, sniOverride: "host.com")

        XCTAssertEqual(a, b)
    }

    func test_equatable_differentValues_returnsFalse() {
        let a = TLSConfiguration(isTLSEnabled: true, allowInsecure: false)
        let b = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)

        XCTAssertNotEqual(a, b)
    }
}
