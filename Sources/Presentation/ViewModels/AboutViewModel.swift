import Foundation

public struct AboutInfo: Equatable {
    public let appName: String
    public let shortDescription: String
    public let marketingVersion: String
    public let buildVersion: String
    public let swiftVersion: String
    public let xcodeVersion: String
    public let developerName: String
    public let developerWebsiteURL: String
    public let githubURL: String
    public let developerEmail: String

    static func from(infoDictionary: [String: Any], appName: String) -> AboutInfo {
        AboutInfo(
            appName: appName,
            shortDescription: stringValue(
                for: "AppShortDescription",
                in: infoDictionary,
                fallback: "No description available."),
            marketingVersion: stringValue(for: "CFBundleShortVersionString", in: infoDictionary),
            buildVersion: stringValue(for: "CFBundleVersion", in: infoDictionary),
            swiftVersion: stringValue(for: "SwiftVersion", in: infoDictionary),
            xcodeVersion: stringValue(for: "XcodeVersion", in: infoDictionary),
            developerName: stringValue(for: "DeveloperName", in: infoDictionary),
            developerWebsiteURL: stringValue(for: "DeveloperWebsiteURL", in: infoDictionary),
            githubURL: stringValue(for: "AppGitHubURL", in: infoDictionary),
            developerEmail: stringValue(for: "DeveloperEmail", in: infoDictionary))
    }

    static func fromBundle(_ bundle: Bundle = .main) -> AboutInfo {
        let infoDictionary = bundle.infoDictionary ?? [:]
        let appName =
            (infoDictionary["CFBundleDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? (infoDictionary["CFBundleName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? "unknown"

        return from(infoDictionary: infoDictionary, appName: appName)
    }

    private static func stringValue(
        for key: String,
        in infoDictionary: [String: Any],
        fallback: String = "unknown")
        -> String
    {
        guard
            let value = infoDictionary[key] as? String,
            let nonEmptyValue = value.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        else {
            return fallback
        }

        return nonEmptyValue
    }
}

public final class AboutViewModel: ObservableObject {
    public let info: AboutInfo

    public init(bundle: Bundle = .main) {
        self.info = AboutInfo.fromBundle(bundle)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
