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
