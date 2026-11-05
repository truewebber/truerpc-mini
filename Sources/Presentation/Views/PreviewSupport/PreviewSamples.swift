#if DEBUG
    import Foundation

    enum PreviewJSON {
        static let shortObject = """
        {
          "userId": 1,
          "name": "Alice"
        }
        """

        static let longDocument: String = {
            let trace = String(repeating: "9f3a7c2e", count: 12)
            return """
            {"traceId":"\(trace)","spanId":"b7c1e4a09d2f48aa"}
            {
              "user": {
                "id": 1,
                "profile": {
                  "displayName": "Alice Smith",
                  "address": {
                    "city": "Berlin",
                    "street": "Unter den Linden 77"
                  }
                }
              }
            }
            """
        }()
    }

    extension ServerEnvironment {
        static let previewLocal = ServerEnvironment(
            name: "Local",
            host: "localhost",
            port: 50051)

        static let previewStaging = ServerEnvironment(
            name: "Staging",
            host: "staging.example.com",
            port: 443,
            tlsConfiguration: TLSConfiguration(isTLSEnabled: true))

        static let previewLongName = ServerEnvironment(
            name: "Production West Europe Customer-Facing Gateway",
            host: "grpc.customer-facing.payments.eu-west-1.internal.example.com",
            port: 443,
            tlsConfiguration: TLSConfiguration(isTLSEnabled: true))
    }

    extension ProtoFile {
        static let previewCatalog: ProtoFile = {
            let getUser = Method(
                name: "GetUser",
                serviceName: "UserService",
                inputType: "GetUserRequest",
                outputType: "GetUserResponse",
                isStreaming: false)
            let streamUsers = Method(
                name: "StreamUsers",
                serviceName: "UserService",
                inputType: "StreamUsersRequest",
                outputType: "User",
                isStreaming: true)
            let service = Service(name: "UserService", methods: [getUser, streamUsers])
            return ProtoFile(
                name: "example.proto",
                path: URL(fileURLWithPath: "/test/example.proto"),
                services: [service])
        }()

        static let previewLongNames: ProtoFile = {
            let method = Method(
                name: "GetUserProfileWithVeryLongMethodNameForLayoutChecks",
                serviceName: "CustomerBillingAndSubscriptionAdminService",
                inputType: "GetUserProfileWithVeryLongMethodNameForLayoutChecksRequest",
                outputType: "GetUserProfileWithVeryLongMethodNameForLayoutChecksResponse",
                isStreaming: true)
            let service = Service(
                name: "CustomerBillingAndSubscriptionAdminService",
                methods: [method])
            return ProtoFile(
                name: "customer_billing_and_subscription_admin_service.proto",
                path: URL(
                    fileURLWithPath: "/Users/shared/protos/billing/customer_billing_and_subscription_admin_service.proto"),
                services: [service])
        }()
    }

    /// Five loaded contracts and tabs opened from all of them, for tab bar and tab switcher previews.
    enum PreviewContracts {
        static let users = contract("users.proto", service: "UserService", methods: [
            "GetUser", "ListUsers", "UpdateUserProfile", "DeleteUser",
        ])
        static let billing = contract("billing.proto", service: "InvoiceService", methods: [
            "CreateInvoice", "ListInvoices", "RefundPayment",
        ])
        static let orders = contract("orders.proto", service: "OrderService", methods: [
            "PlaceOrder", "CancelOrder", "TrackShipment",
        ])
        static let inventory = contract("inventory.proto", service: "StockService", methods: [
            "ReserveStock", "ReleaseStock",
        ])
        static let notifications = contract("notifications.proto", service: "PushService", methods: [
            "SendPush", "StreamDeliveryReceipts",
        ])

        static let all = [users, billing, orders, inventory, notifications]

        static let colorSlots: [URL: Int] = Dictionary(
            uniqueKeysWithValues: all.enumerated().map { ($1.path, $0) })

        /// Tabs interleaved across contracts, the way they pile up during a working day.
        static let mixedTabs: [EditorTab] = [
            tab("GetUser", in: users),
            tab("CreateInvoice", in: billing),
            tab("PlaceOrder", in: orders),
            tab("ListUsers", in: users),
            tab("ReserveStock", in: inventory),
            tab("SendPush", in: notifications),
            tab("RefundPayment", in: billing),
            tab("TrackShipment", in: orders),
            tab("UpdateUserProfile", in: users),
            tab("StreamDeliveryReceipts", in: notifications),
        ]

        static let longNameTabs: [EditorTab] = {
            let protoFile = ProtoFile.previewLongNames
            let service = protoFile.services[0]
            let method = service.methods[0]
            return [
                EditorTab(methodName: method.name, serviceName: service.name, protoFile: protoFile, method: method),
                EditorTab(
                    methodName: "GetUserProfileWithVeryLongMethodNameForAuditTrail",
                    serviceName: service.name,
                    protoFile: protoFile,
                    method: method),
                tab("GetUser", in: users),
            ]
        }()

        static let longNameColorSlots: [URL: Int] = colorSlots.merging(
            [ProtoFile.previewLongNames.path: 5],
            uniquingKeysWith: { first, _ in first })

        /// Enough tabs to overflow any window width.
        static let manyTabs: [EditorTab] = (0 ..< 6).flatMap { round in
            all.flatMap { protoFile in
                protoFile.services[0].methods.map { method in
                    EditorTab(
                        methodName: round == 0 ? method.name : "\(method.name)V\(round + 1)",
                        serviceName: method.serviceName,
                        protoFile: protoFile,
                        method: method)
                }
            }
        }

        private static func contract(_ name: String, service: String, methods: [String]) -> ProtoFile {
            let methods = methods.map {
                Method(
                    name: $0,
                    serviceName: service,
                    inputType: "\($0)Request",
                    outputType: "\($0)Response",
                    isStreaming: $0.hasPrefix("Stream"))
            }
            return ProtoFile(
                name: name,
                path: URL(fileURLWithPath: "/Users/shared/protos/\(name)"),
                services: [Service(name: service, methods: methods)])
        }

        private static func tab(_ methodName: String, in protoFile: ProtoFile) -> EditorTab {
            let service = protoFile.services[0]
            let method = service.methods.first { $0.name == methodName } ?? service.methods[0]
            return EditorTab(methodName: method.name, serviceName: service.name, protoFile: protoFile, method: method)
        }
    }

    extension GrpcResponse {
        static let previewSuccess = GrpcResponse(
            jsonBody: PreviewJSON.shortObject,
            responseTime: 0.156,
            statusCode: 0,
            statusMessage: "OK",
            headers: ["content-type": "application/grpc"])

        static let previewFailure = GrpcResponse(
            jsonBody: """
            {
              "code": 7,
              "message": "permission denied"
            }
            """,
            responseTime: 0.042,
            statusCode: 7,
            statusMessage: "PERMISSION_DENIED",
            trailers: ["grpc-status": "7", "grpc-message": "permission denied"])

        static let previewLong = GrpcResponse(
            jsonBody: PreviewJSON.longDocument,
            responseTime: 12.345,
            statusCode: 0,
            statusMessage: "OK: the remote handler accepted the request and returned a very long status description")
    }

    @MainActor
    enum PreviewGlobalEnvironments {
        static func viewModel(
            environments: [ServerEnvironment] = [.previewLocal, .previewStaging],
            selected: ServerEnvironment? = nil)
            -> GlobalEnvironmentViewModel
        {
            let viewModel = GlobalEnvironmentViewModel(
                loadEnvironmentsUseCase: Load(environments: environments),
                saveEnvironmentUseCase: Save(),
                deleteEnvironmentUseCase: Delete(),
                selectEnvironmentUseCase: Select(),
                getSelectedEnvironmentUseCase: Selected(environment: selected))
            viewModel.loadEnvironments()
            return viewModel
        }

        private struct Load: LoadEnvironmentsUseCaseProtocol {
            let environments: [ServerEnvironment]

            func execute() -> [ServerEnvironment] {
                environments
            }
        }

        private struct Save: SaveEnvironmentUseCaseProtocol {
            func execute(_: ServerEnvironment) {}
        }

        private struct Delete: DeleteEnvironmentUseCaseProtocol {
            func execute(id _: UUID) {}
        }

        private struct Select: SelectEnvironmentUseCaseProtocol {
            func execute(_: ServerEnvironment?) {}
        }

        private struct Selected: GetSelectedEnvironmentUseCaseProtocol {
            let environment: ServerEnvironment?

            func execute() -> ServerEnvironment? {
                environment
            }
        }
    }
#endif
