#if DEBUG

    import XCTest
    @testable import TrueRPCMini

    final class AppLaunchTests: XCTestCase {
        func test_init_whenArgumentIsAbsent_isNormal() {
            let launch = AppLaunch(arguments: [])

            XCTAssertEqual(launch, .normal)
            XCTAssertNil(launch.autocompleteProvider)
            XCTAssertNil(launch.editor)
        }

        func test_init_whenUnrelatedArgumentsArePresent_isNormal() {
            let launch = AppLaunch(arguments: ["-AppleLanguages", "(en)"])

            XCTAssertEqual(launch, .normal)
            XCTAssertNil(launch.autocompleteProvider)
            XCTAssertNil(launch.editor)
        }

        func test_init_whenUITestingArgumentIsPresent_isUITesting() {
            let launch = AppLaunch(arguments: [AppLaunch.uiTestingArgument])

            XCTAssertEqual(launch, .uiTesting)
        }

        func test_init_whenUITestingArgumentIsAmongOthers_isUITesting() {
            let launch = AppLaunch(arguments: ["-NSSomething", AppLaunch.uiTestingArgument, "extra"])

            XCTAssertEqual(launch, .uiTesting)
        }

        func test_init_whenUITesting_usesTheFixtureAutocompleteProvider() {
            let launch = AppLaunch(arguments: [AppLaunch.uiTestingArgument])

            XCTAssertTrue(launch.autocompleteProvider is UITestAutocompleteProvider)
        }

        func test_init_whenUITesting_opensTheFixtureEditor() throws {
            let launch = AppLaunch(arguments: [AppLaunch.uiTestingArgument])
            let editor = try XCTUnwrap(launch.editor)

            XCTAssertEqual(editor.method.name, "TestMethod")
            XCTAssertEqual(editor.method.inputType, ".uitest.TestRequest")
            XCTAssertEqual(editor.method.outputType, ".uitest.TestResponse")
            XCTAssertFalse(editor.method.isStreaming)
            XCTAssertEqual(editor.service.name, "TestService")
            XCTAssertEqual(editor.service.methods, [editor.method])
            XCTAssertEqual(editor.protoFile.name, "uitest.proto")
            XCTAssertEqual(editor.protoFile.path, URL(fileURLWithPath: "/tmp/uitest.proto"))
            XCTAssertEqual(editor.protoFile.services, [editor.service])
        }
    }

#endif
