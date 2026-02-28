import Foundation

extension UserDefaults {
    public static var analyticsOptOutKey: String {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            preconditionFailure("Bundle identifier is required for analytics opt-out key.")
        }
        return "\(bundleIdentifier).analytics.optOut"
    }

    public var analyticsOptOut: Bool {
        get { bool(forKey: Self.analyticsOptOutKey) }
        set { set(newValue, forKey: Self.analyticsOptOutKey) }
    }

    public static func runAnalyticsOptOutMigration(on userDefaults: UserDefaults = .standard) {
        if userDefaults.object(forKey: analyticsOptOutKey) == nil {
            userDefaults.set(true, forKey: analyticsOptOutKey)
        }
    }
}
