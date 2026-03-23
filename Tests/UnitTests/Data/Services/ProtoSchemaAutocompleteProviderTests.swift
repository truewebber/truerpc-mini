import SwiftProtoReflect
import XCTest
@testable import TrueRPCMini

final class ProtoSchemaAutocompleteProviderTests: XCTestCase {
    private var sut: ProtoSchemaAutocompleteProvider!
    private var protoFile: ProtoFile!

    override func setUp() {
        super.setUp()

        let file = FileDescriptor(name: "test.proto", package: "test")

        var rootMsg = MessageDescriptor(name: "TestRequest", parent: file)
        rootMsg.addField(FieldDescriptor(name: "name", number: 1, type: .string))
        rootMsg.addField(FieldDescriptor(name: "count", number: 2, type: .int32))
        rootMsg.addField(FieldDescriptor(name: "settings", number: 3, type: .message, typeName: "test.Settings"))
        rootMsg.addField(FieldDescriptor(name: "status", number: 4, type: .enum, typeName: "test.TestRequest.Status"))
        rootMsg.addField(
            FieldDescriptor(
                name: "tags",
                number: 5,
                type: .enum,
                typeName: "test.TestRequest.Status",
                isRepeated: true))

        var statusEnum = EnumDescriptor(name: "Status", parent: rootMsg)
        statusEnum.addValue(EnumDescriptor.EnumValue(name: "UNKNOWN", number: 0))
        statusEnum.addValue(EnumDescriptor.EnumValue(name: "ACTIVE", number: 1))
        statusEnum.addValue(EnumDescriptor.EnumValue(name: "INACTIVE", number: 2))
        rootMsg.addNestedEnum(statusEnum)

        var settingsMsg = MessageDescriptor(name: "Settings", parent: file)
        settingsMsg.addField(FieldDescriptor(name: "enabled", number: 1, type: .bool))

        let repo = StubProtoRepository(descriptors: [
            "test.TestRequest": rootMsg,
            "test.Settings": settingsMsg,
        ])

        sut = ProtoSchemaAutocompleteProvider(protoRepository: repo)

        let method = Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: "test.TestRequest",
            outputType: "test.TestResponse")
        let service = Service(name: "TestService", methods: [method])
        protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test.proto"),
            services: [service])
    }

    override func tearDown() {
        sut = nil
        protoFile = nil
        super.tearDown()
    }

    // MARK: - Key mode

    func test_suggestions_forRootMessage_returnsAllFields() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, in: protoFile)

        XCTAssertEqual(suggestions.count, 6)
        XCTAssertEqual(suggestions[0].kind, .fillDefaults)
        let fieldNames = Set(suggestions.dropFirst().map(\.name))
        XCTAssertEqual(fieldNames, Set(["name", "count", "settings", "status", "tags"]))
    }

    func test_suggestions_forNestedMessage_returnsNestedFields() async {
        let context = AutocompleteContext(resolvedPath: ["settings"], mode: .key)

        let suggestions = await sut.suggestions(for: context, in: protoFile)

        XCTAssertEqual(suggestions.count, 2)
        XCTAssertEqual(suggestions[0].kind, .fillDefaults)
        XCTAssertEqual(suggestions[1].name, "enabled")
        XCTAssertEqual(suggestions[1].kind, .bool)
    }

    func test_suggestions_keyMode_prependsFillDefaults() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, in: protoFile)

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions.first?.kind, .fillDefaults)
        XCTAssertEqual(suggestions.first?.name, "fillDefaults")
    }

    func test_suggestions_withOneOfField_setsOneOfGroup() async {
        let file = FileDescriptor(name: "o.proto", package: "pkg")
        var msg = MessageDescriptor(name: "Req", parent: file)
        msg.addOneofDecl(OneofDescriptor(name: "choice", index: 0))
        msg.addField(FieldDescriptor(name: "opt_a", number: 1, type: .string, oneofIndex: 0))
        msg.addField(FieldDescriptor(name: "opt_b", number: 2, type: .int32, oneofIndex: 0))
        msg.addField(FieldDescriptor(name: "regular", number: 3, type: .bool))

        let repo = StubProtoRepository(descriptors: ["pkg.Req": msg])
        let provider = ProtoSchemaAutocompleteProvider(protoRepository: repo)

        let method = Method(name: "Do", serviceName: "Svc", inputType: "pkg.Req", outputType: "pkg.Resp")
        let service = Service(name: "Svc", methods: [method])
        let pf = ProtoFile(name: "o.proto", path: URL(fileURLWithPath: "/o.proto"), services: [service])

        let context = AutocompleteContext(resolvedPath: [], mode: .key)
        let suggestions = await provider.suggestions(for: context, in: pf)

        let optA = suggestions.first(where: { $0.name == "opt_a" })
        let optB = suggestions.first(where: { $0.name == "opt_b" })
        let regular = suggestions.first(where: { $0.name == "regular" })

        XCTAssertEqual(optA?.oneOfGroup, "choice")
        XCTAssertEqual(optB?.oneOfGroup, "choice")
        XCTAssertNil(regular?.oneOfGroup)
    }

    // MARK: - Enum value mode

    func test_suggestions_forEnumValueMode_returnsEnumCases() async {
        let context = AutocompleteContext(resolvedPath: ["status"], mode: .enumValue)

        let suggestions = await sut.suggestions(for: context, in: protoFile)

        XCTAssertEqual(suggestions.count, 3)
        XCTAssertTrue(suggestions.allSatisfy { $0.kind == .enum })
        let names = Set(suggestions.map(\.name))
        XCTAssertEqual(names, Set(["UNKNOWN", "ACTIVE", "INACTIVE"]))
    }

    // MARK: - Unknown path

    func test_suggestions_forUnknownPath_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: ["unknown_field"], mode: .key)

        let suggestions = await sut.suggestions(for: context, in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    // MARK: - Array element mode

    func test_suggestions_forArrayElementOfEnum_returnsEnumCases() async {
        let context = AutocompleteContext(resolvedPath: ["tags"], mode: .arrayElement)

        let suggestions = await sut.suggestions(for: context, in: protoFile)

        XCTAssertEqual(suggestions.count, 3)
        XCTAssertTrue(suggestions.allSatisfy { $0.kind == .enum })
        let names = Set(suggestions.map(\.name))
        XCTAssertEqual(names, Set(["UNKNOWN", "ACTIVE", "INACTIVE"]))
    }
}
