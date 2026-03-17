import XCTest
@testable import TrueRPCMini

/// Tests for ConnectionSecurityViewModel — TLS state management for a single editor tab
@MainActor
final class ConnectionSecurityViewModelTests: XCTestCase {
    var sut: ConnectionSecurityViewModel!

    override func setUp() async throws {
        try await super.setUp()
        sut = ConnectionSecurityViewModel()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - lockState

    func test_lockState_whenPlaintext_returnsPlaintext() {
        sut.update(activeEnvironment: nil, restoredAdHocConfig: nil)

        XCTAssertEqual(sut.lockState, .plaintext)
    }

    func test_lockState_whenSecureTLS_returnsSecure() {
        let config = TLSConfiguration(isTLSEnabled: true)
        sut.update(activeEnvironment: nil, restoredAdHocConfig: config)

        XCTAssertEqual(sut.lockState, .secure)
    }

    func test_lockState_whenInsecureTLS_returnsInsecure() {
        let config = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)
        sut.update(activeEnvironment: nil, restoredAdHocConfig: config)

        XCTAssertEqual(sut.lockState, .insecure)
    }

    // MARK: - isEnvironmentMode

    func test_isEnvironmentMode_whenEnvironmentSet_returnsTrue() {
        let env = ServerEnvironment(name: "Production", host: "localhost", port: 50051)
        sut.update(activeEnvironment: env, restoredAdHocConfig: nil)

        XCTAssertTrue(sut.isEnvironmentMode)
    }

    func test_isEnvironmentMode_whenNoEnvironment_returnsFalse() {
        sut.update(activeEnvironment: nil, restoredAdHocConfig: nil)

        XCTAssertFalse(sut.isEnvironmentMode)
    }

    // MARK: - effectiveTLSConfiguration

    func test_effectiveTLSConfiguration_inEnvironmentMode_returnsEnvConfig() {
        let tlsConfig = TLSConfiguration(isTLSEnabled: true)
        let env = ServerEnvironment(
            name: "Production",
            host: "localhost",
            port: 50051,
            tlsConfiguration: tlsConfig)
        sut.update(activeEnvironment: env, restoredAdHocConfig: nil)

        XCTAssertEqual(sut.effectiveTLSConfiguration, tlsConfig)
    }

    func test_effectiveTLSConfiguration_inCustomMode_returnsAdHocConfig() {
        let adHocConfig = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)
        sut.update(activeEnvironment: nil, restoredAdHocConfig: adHocConfig)

        XCTAssertEqual(sut.effectiveTLSConfiguration, adHocConfig)
    }

    // MARK: - update transitions

    func test_update_switchingToEnvironmentMode_updatesLockState() {
        sut.update(activeEnvironment: nil, restoredAdHocConfig: nil)
        XCTAssertEqual(sut.lockState, .plaintext)

        let tlsConfig = TLSConfiguration(isTLSEnabled: true)
        let env = ServerEnvironment(
            name: "Production",
            host: "localhost",
            port: 50051,
            tlsConfiguration: tlsConfig)
        sut.update(activeEnvironment: env, restoredAdHocConfig: nil)

        XCTAssertEqual(sut.lockState, .secure)
        XCTAssertTrue(sut.isEnvironmentMode)
    }

    func test_update_switchingToCustomMode_restoresAdHocConfig() {
        let adHocConfig = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)
        let env = ServerEnvironment(name: "Production", host: "localhost", port: 50051)
        sut.update(activeEnvironment: env, restoredAdHocConfig: adHocConfig)
        XCTAssertTrue(sut.isEnvironmentMode)

        sut.update(activeEnvironment: nil, restoredAdHocConfig: adHocConfig)

        XCTAssertFalse(sut.isEnvironmentMode)
        XCTAssertEqual(sut.adHocConfig, adHocConfig)
        XCTAssertEqual(sut.lockState, .insecure)
    }
}
