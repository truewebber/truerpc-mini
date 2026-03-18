import Foundation
import XCTest

final class ReleaseWorkflowTests: XCTestCase {
    func test_releaseWorkflow_includesZipArtifactInReleaseAssets() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("ZIP_NAME=\"TrueRPCMini-${{ github.ref_name }}.zip\""),
            "Release workflow must define ZIP_NAME for Sparkle-compatible artifact")
        XCTAssertTrue(
            workflow.contains("TrueRPCMini-${{ github.ref_name }}.zip"),
            "Release workflow must upload ZIP artifact to GitHub Release assets")
    }

    func test_releaseWorkflow_includesDmgArtifact_noRegression() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("DMG_NAME=\"TrueRPCMini-${{ github.ref_name }}.dmg\""),
            "Release workflow must still define DMG_NAME (no regression)")
        XCTAssertTrue(
            workflow.contains("TrueRPCMini-${{ github.ref_name }}.dmg"),
            "Release workflow must still upload DMG artifact to GitHub Release assets (no regression)")
    }

    func test_releaseWorkflow_artifactNamesAreVersionConsistent() throws {
        let workflow = try loadReleaseWorkflow()
        let tag = "${{ github.ref_name }}"

        XCTAssertTrue(
            workflow.contains("TrueRPCMini-\(tag).dmg"),
            "DMG artifact name must derive version from github.ref_name tag")
        XCTAssertTrue(
            workflow.contains("TrueRPCMini-\(tag).zip"),
            "ZIP artifact name must derive version from github.ref_name tag")
    }

    func test_releaseWorkflow_buildNumberIsCommitCount_notGitSha() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("git rev-list --count HEAD"),
            "CURRENT_PROJECT_VERSION must use commit count (monotonically increasing integer) so Sparkle can compare versions")
        XCTAssertFalse(
            workflow.contains("git rev-parse --short HEAD"),
            "CURRENT_PROJECT_VERSION must NOT use a git SHA — Sparkle cannot compare non-numeric strings")
    }

    func test_releaseWorkflow_checkoutFetchesFullHistory() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("fetch-depth: 0"),
            "Checkout must use fetch-depth: 0 so git rev-list --count HEAD returns the real commit count, not 1 (shallow clone)")
    }

    func test_releaseWorkflow_zipIsNotarized() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("notarytool submit \"$ZIP_NAME\""),
            "ZIP artifact must be submitted to notarytool so Sparkle updates pass Gatekeeper")
    }

    func test_releaseWorkflow_dmgIsNotarizedAndStapled() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("notarytool submit \"$DMG_NAME\""),
            "DMG artifact must be submitted to notarytool (no regression)")
        XCTAssertTrue(
            workflow.contains("xcrun stapler staple \"$DMG_NAME\""),
            "DMG must be stapled after notarization (no regression)")
    }

    func test_releaseWorkflow_zipCreatedWithDitto() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("ditto -c -k --sequesterRsrc --keepParent"),
            "ZIP must be created using ditto for correct Sparkle-compatible archive structure")
    }

    func test_releaseWorkflow_codesign_signsSparkleXpcServices() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("*.xpc"),
            "Codesign step must explicitly sign XPC services nested in Sparkle.framework")
    }

    func test_releaseWorkflow_codesign_signsNestedAppBundles() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("Contents/Frameworks") && workflow.contains("*.app"),
            "Codesign step must explicitly sign nested .app bundles (e.g. Sparkle's Updater.app)")
    }

    func test_releaseWorkflow_codesign_signsStandaloneMachOInsideFrameworks() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("Mach-O"),
            "Codesign step must detect and sign standalone Mach-O executables inside frameworks (e.g. Sparkle's Autoupdate)")
    }

    func test_releaseWorkflow_secretsXcconfig_writesSparkleAppcastUrl() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("SPARKLE_APPCAST_URL_REMAINDER = truewebber.github.io/truerpc-mini/appcast.xml"),
            "Secrets.xcconfig generation must write SPARKLE_APPCAST_URL_REMAINDER so release builds have SUFeedURL")
    }

    func test_releaseWorkflow_secretsXcconfig_writesSparkleEdPublicKey() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("SPARKLE_ED_PUBLIC_KEY"),
            "Secrets.xcconfig generation must inject SPARKLE_ED_PUBLIC_KEY so release builds reject unsigned updates")
    }

    func test_releaseWorkflow_signsZipAndGeneratesAppcastWithEdDSAKey() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("SPARKLE_ED_PRIVATE_KEY"),
            "Workflow must reference SPARKLE_ED_PRIVATE_KEY secret for EdDSA signing")
        XCTAssertTrue(
            workflow.contains("generate_appcast"),
            "Workflow must call generate_appcast to produce the Sparkle feed")
        XCTAssertTrue(
            workflow.contains("--ed-key-file -"),
            "generate_appcast must receive the private key via stdin (--ed-key-file -)")
        XCTAssertTrue(
            workflow.contains("echo \"$SPARKLE_ED_PRIVATE_KEY\" |"),
            "Private key must be piped to generate_appcast via stdin to avoid shell history exposure")
    }

    func test_releaseWorkflow_appcastDownloadUrlPointsToGithubRelease() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("--download-url-prefix"),
            "generate_appcast must use --download-url-prefix to point downloads at GitHub Releases")
        XCTAssertTrue(
            workflow.contains("/releases/download/"),
            "Appcast download URL prefix must reference the GitHub Releases download path")
    }

    func test_releaseWorkflow_appcastIsPublishedToGhPages() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("gh-pages"),
            "Workflow must publish appcast.xml to the gh-pages branch for stable Sparkle feed URL")
        XCTAssertTrue(
            workflow.contains("push origin gh-pages"),
            "Workflow must push the appcast.xml update to the gh-pages branch")
    }

    func test_releaseWorkflow_appcastStepFailsExplicitlyWhenPrivateKeyMissing() throws {
        let workflow = try loadReleaseWorkflow()

        XCTAssertTrue(
            workflow.contains("SPARKLE_ED_PRIVATE_KEY secret is not set"),
            "Workflow must fail with an explicit error when SPARKLE_ED_PRIVATE_KEY is missing")
    }

    private func loadReleaseWorkflow() throws -> String {
        let filePath = URL(fileURLWithPath: #filePath)
        let repositoryRoot = filePath
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // UnitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
        let workflowURL = repositoryRoot
            .appendingPathComponent(".github")
            .appendingPathComponent("workflows")
            .appendingPathComponent("release-macos.yml")

        return try String(contentsOf: workflowURL, encoding: .utf8)
    }
}
