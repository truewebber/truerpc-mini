import XCTest
@testable import TrueRPCMini

final class AboutViewModelTests: XCTestCase {
    func test_fromInfoDictionary_whenAllFieldsProvided_mapsAllValues() {
        let info = AboutInfo.from(
            infoDictionary: [
                "CFBundleShortVersionString": "1.2.3",
                "CFBundleVersion": "456",
                "AppShortDescription": "Dynamic gRPC client for .proto files.",
                "SwiftVersion": "6.2.4",
                "XcodeVersion": "16.3",
                "DeveloperName": "TrueWebber",
                "DeveloperWebsiteURL": "https://truewebber.com",
                "AppGitHubURL": "https://github.com/truewebber/truerpc-mini",
                "DeveloperEmail": "hello@truewebber.com",
            ],
            appName: "TrueRPC Mini")

        XCTAssertEqual(info.appName, "TrueRPC Mini")
        XCTAssertEqual(info.shortDescription, "Dynamic gRPC client for .proto files.")
        XCTAssertEqual(info.marketingVersion, "1.2.3")
        XCTAssertEqual(info.buildVersion, "456")
        XCTAssertEqual(info.swiftVersion, "6.2.4")
        XCTAssertEqual(info.xcodeVersion, "16.3")
        XCTAssertEqual(info.developerName, "TrueWebber")
        XCTAssertEqual(info.developerWebsiteURL, "https://truewebber.com")
        XCTAssertEqual(info.githubURL, "https://github.com/truewebber/truerpc-mini")
        XCTAssertEqual(info.developerEmail, "hello@truewebber.com")
    }

    func test_fromInfoDictionary_whenValuesMissing_usesUnknownFallback() {
        let info = AboutInfo.from(infoDictionary: [:], appName: "TrueRPC Mini")

        XCTAssertEqual(info.shortDescription, "No description available.")
        XCTAssertEqual(info.marketingVersion, "unknown")
        XCTAssertEqual(info.buildVersion, "unknown")
        XCTAssertEqual(info.swiftVersion, "unknown")
        XCTAssertEqual(info.xcodeVersion, "unknown")
        XCTAssertEqual(info.developerName, "unknown")
        XCTAssertEqual(info.developerWebsiteURL, "unknown")
        XCTAssertEqual(info.githubURL, "unknown")
        XCTAssertEqual(info.developerEmail, "unknown")
    }
}
