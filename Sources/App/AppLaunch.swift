#if DEBUG

    import Foundation

    /// Debug-only launch mode read from process arguments.
    /// Release builds do not compile this type, so a release binary has no UI-test fixture.
    enum AppLaunch: Equatable, Sendable {
        case normal
        case uiTesting

        /// Passed by UI tests through `XCUIApplication.launchArguments`.
        static let uiTestingArgument = "--uitesting"

        init(arguments: [String]) {
            self = arguments.contains(Self.uiTestingArgument) ? .uiTesting : .normal
        }

        /// The autocomplete provider for this launch. `nil` means the production provider.
        var autocompleteProvider: (any AutocompleteProviderProtocol)? {
            switch self {
            case .normal:
                nil
            case .uiTesting:
                UITestAutocompleteProvider()
            }
        }

        /// The editor opened on launch. `nil` leaves the window on its usual restored tabs.
        var editor: Editor? {
            switch self {
            case .normal:
                nil
            case .uiTesting:
                .uiTest
            }
        }

        /// Fixed contract so a UI test can type into the JSON editor without importing a proto.
        struct Editor: Equatable, Sendable {
            let method: Method
            let service: Service
            let protoFile: ProtoFile

            static let uiTest: Editor = {
                let method = Method(
                    name: "TestMethod",
                    inputType: ".uitest.TestRequest",
                    outputType: ".uitest.TestResponse",
                    isStreaming: false)
                let service = Service(name: "TestService", methods: [method])
                let protoFile = ProtoFile(
                    name: "uitest.proto",
                    path: URL(fileURLWithPath: "/tmp/uitest.proto"),
                    services: [service])
                return Editor(method: method, service: service, protoFile: protoFile)
            }()
        }
    }

#endif
