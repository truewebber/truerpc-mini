import Foundation

public extension UserDefaults {
    static var analyticsIsEnabledKey: String {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            preconditionFailure("Bundle identifier is required for analytics key.")
        }

        return "\(bundleIdentifier).analytics.isEnabled"
    }

    /// Returns `true` if analytics tracking is enabled.
    ///
    /// Call `runAnalyticsMigration()` once at app launch to ensure a stored
    /// value exists and defaults to `true`.
    var analyticsIsEnabled: Bool {
        get { bool(forKey: Self.analyticsIsEnabledKey) }
        set { set(newValue, forKey: Self.analyticsIsEnabledKey) }
    }

    /// Sets `analyticsIsEnabled = true` on the very first launch when no value
    /// has been stored yet.
    static func runAnalyticsMigration(on userDefaults: UserDefaults = .standard) {
        if userDefaults.object(forKey: analyticsIsEnabledKey) == nil {
            userDefaults.analyticsIsEnabled = true
        }
    }
}
