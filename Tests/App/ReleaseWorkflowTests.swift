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

    private func loadReleaseWorkflow() throws -> String {
        let filePath = URL(fileURLWithPath: #filePath)
        let repositoryRoot = filePath
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
        let workflowURL = repositoryRoot
            .appendingPathComponent(".github")
            .appendingPathComponent("workflows")
            .appendingPathComponent("release-macos.yml")

        return try String(contentsOf: workflowURL, encoding: .utf8)
    }
}
