import XCTest
@testable import TrueRPCMini

final class EditorTabStateTests: XCTestCase {
    // MARK: - Init

    func test_init_storesAllProperties() {
        let id = UUID()
        let state = EditorTabState(
            id: id,
            protoFilePath: "/path/to/file.proto",
            serviceName: "UserService",
            methodName: "GetUser")

        XCTAssertEqual(state.id, id)
        XCTAssertEqual(state.protoFilePath, "/path/to/file.proto")
        XCTAssertEqual(state.serviceName, "UserService")
        XCTAssertEqual(state.methodName, "GetUser")
    }

    func test_init_withSelectedEnvironmentId_storesValue() {
        let envId = UUID()
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/p.proto",
            serviceName: "S",
            methodName: "M",
            selectedEnvironmentId: envId)

        XCTAssertEqual(state.selectedEnvironmentId, envId)
    }

    func test_init_withoutSelectedEnvironmentId_isNil() {
        let state = EditorTabState(
            id: UUID(),
            protoFilePath: "/p.proto",
            serviceName: "S",
            methodName: "M")

        XCTAssertNil(state.selectedEnvironmentId)
    }

    func test_init_fromEditorTabAndTabEnvironment_storesEnvId() {
        let method = Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".user.GetUserRequest",
            outputType: ".user.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "user.proto",
            path: URL(fileURLWithPath: "/test/user.proto"),
            services: [service])
        let editorTab = EditorTab(
            id: UUID(),
            methodName: "GetUser",
            serviceName: "UserService",
            protoFile: protoFile,
            method: method)
        let env = ServerEnvironment(id: UUID(), name: "Dev", host: "localhost", port: 50051)

        let state = EditorTabState(editorTab: editorTab, tabEnvironment: env)

        XCTAssertEqual(state.selectedEnvironmentId, env.id)
    }

    func test_init_fromEditorTabAndNilTabEnvironment_storesNilEnvId() {
        let method = Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".user.GetUserRequest",
            outputType: ".user.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "user.proto",
            path: URL(fileURLWithPath: "/test/user.proto"),
            services: [service])
        let editorTab = EditorTab(
            id: UUID(),
            methodName: "GetUser",
            serviceName: "UserService",
            protoFile: protoFile,
            method: method)

        let state = EditorTabState(editorTab: editorTab, tabEnvironment: nil)

        XCTAssertNil(state.selectedEnvironmentId)
    }

    func test_init_fromEditorTabAndCustomUrl_storesCustomUrl() {
        let method = Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".user.GetUserRequest",
            outputType: ".user.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "user.proto",
            path: URL(fileURLWithPath: "/test/user.proto"),
            services: [service])
        let editorTab = EditorTab(
            id: UUID(),
            methodName: "GetUser",
            serviceName: "UserService",
            protoFile: protoFile,
            method: method)

        let state = EditorTabState(editorTab: editorTab, tabEnvironment: nil, customUrl: "custom:9090")

        XCTAssertNil(state.selectedEnvironmentId)
        XCTAssertEqual(state.customUrl, "custom:9090")
    }

    func test_init_fromEditorTabWithTabEnvironment_clearsCustomUrl() {
        let method = Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".user.GetUserRequest",
            outputType: ".user.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "user.proto",
            path: URL(fileURLWithPath: "/test/user.proto"),
            services: [service])
        let editorTab = EditorTab(
            id: UUID(),
            methodName: "GetUser",
            serviceName: "UserService",
            protoFile: protoFile,
            method: method)
        let env = ServerEnvironment(id: UUID(), name: "Dev", host: "localhost", port: 50051)

        let state = EditorTabState(editorTab: editorTab, tabEnvironment: env, customUrl: "custom:9090")

        XCTAssertEqual(state.selectedEnvironmentId, env.id)
        XCTAssertNil(state.customUrl)
    }

    func test_init_fromEditorTab_createsMatchingState() {
        let method = Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".user.GetUserRequest",
            outputType: ".user.User")
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "user.proto",
            path: URL(fileURLWithPath: "/test/user.proto"),
            services: [service])
        let editorTab = EditorTab(
            id: UUID(),
            methodName: "GetUser",
            serviceName: "UserService",
            protoFile: protoFile,
            method: method)

        let state = EditorTabState(editorTab: editorTab)

        XCTAssertEqual(state.id, editorTab.id)
        XCTAssertEqual(state.protoFilePath, "/test/user.proto")
        XCTAssertEqual(state.serviceName, "UserService")
        XCTAssertEqual(state.methodName, "GetUser")
    }

    // MARK: - Codable

    func test_codable_roundtrip_preservesData() throws {
        let original = EditorTabState(
            id: UUID(),
            protoFilePath: "/tmp/test.proto",
            serviceName: "TestService",
            methodName: "TestMethod")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EditorTabState.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func test_codable_roundtrip_withCustomUrl_preservesCustomUrl() throws {
        let original = EditorTabState(
            id: UUID(),
            protoFilePath: "/tmp/test.proto",
            serviceName: "TestService",
            methodName: "TestMethod",
            customUrl: "localhost:9090")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EditorTabState.self, from: data)

        XCTAssertEqual(decoded.customUrl, "localhost:9090")
    }

    func test_codable_roundtrip_withSelectedEnvironmentId_preservesEnvId() throws {
        let envId = UUID()
        let original = EditorTabState(
            id: UUID(),
            protoFilePath: "/tmp/test.proto",
            serviceName: "TestService",
            methodName: "TestMethod",
            selectedEnvironmentId: envId)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EditorTabState.self, from: data)

        XCTAssertEqual(decoded.selectedEnvironmentId, envId)
    }

    // MARK: - Equatable

    func test_equatable_sameValues_returnsTrue() {
        let id = UUID()
        let a = EditorTabState(id: id, protoFilePath: "/p.proto", serviceName: "S", methodName: "M")
        let b = EditorTabState(id: id, protoFilePath: "/p.proto", serviceName: "S", methodName: "M")

        XCTAssertEqual(a, b)
    }

    func test_equatable_differentId_returnsFalse() {
        let a = EditorTabState(id: UUID(), protoFilePath: "/p.proto", serviceName: "S", methodName: "M")
        let b = EditorTabState(id: UUID(), protoFilePath: "/p.proto", serviceName: "S", methodName: "M")

        XCTAssertNotEqual(a, b)
    }

    // MARK: - Identifiable

    func test_identifiable_idReturnsCorrectValue() {
        let id = UUID()
        let state = EditorTabState(id: id, protoFilePath: "/p.proto", serviceName: "S", methodName: "M")

        XCTAssertEqual(state.id, id)
    }
}
