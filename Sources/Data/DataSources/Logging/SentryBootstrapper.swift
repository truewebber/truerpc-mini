import Sentry
import Foundation

/// Initializes the Sentry SDK at app launch.
///
/// Call once in the composition root, in Release builds only.
/// Keeping `import Sentry` confined to this file satisfies the constraint
/// that no App-layer source needs a direct Sentry import.
struct SentryBootstrapper {
    static func start(dsn: String) {
        SentrySDK.start { options in
            options.dsn = dsn
            options.experimental.enableLogs = true
            options.environment = "production"
        }
    }
}
