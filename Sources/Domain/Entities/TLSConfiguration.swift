import Foundation

/// Represents the visual security state of a gRPC connection
public enum LockIndicatorState: Equatable, Sendable {
    /// No TLS — plaintext connection (grey)
    case plaintext
    /// TLS with standard or mTLS — fully verified (green)
    case secure
    /// TLS with relaxed verification or custom CA (yellow)
    case insecure
}

/// Represents all TLS/security settings for a gRPC connection
public struct TLSConfiguration: Equatable, Codable, Sendable {
    public var isTLSEnabled: Bool
    public var allowInsecure: Bool
    public var customCAURL: URL?
    public var clientCertURL: URL?
    public var clientKeyURL: URL?
    public var sniOverride: String?

    public init(
        isTLSEnabled: Bool = false,
        allowInsecure: Bool = false,
        customCAURL: URL? = nil,
        clientCertURL: URL? = nil,
        clientKeyURL: URL? = nil,
        sniOverride: String? = nil)
    {
        self.isTLSEnabled = isTLSEnabled
        self.allowInsecure = allowInsecure
        self.customCAURL = customCAURL
        self.clientCertURL = clientCertURL
        self.clientKeyURL = clientKeyURL
        self.sniOverride = sniOverride
    }

    /// Returns a plaintext (no TLS) configuration as the default
    public static var defaults: TLSConfiguration {
        TLSConfiguration()
    }

    /// Indicates the UI lock state derived from the current TLS settings
    public var lockIndicatorState: LockIndicatorState {
        guard isTLSEnabled else { return .plaintext }

        if allowInsecure || customCAURL != nil { return .insecure }
        return .secure
    }
}
