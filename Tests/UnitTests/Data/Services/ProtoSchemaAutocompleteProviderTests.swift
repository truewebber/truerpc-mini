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
        rootMsg.addField(FieldDescriptor(name: "score", number: 6, type: .double))
        rootMsg.addField(FieldDescriptor(name: "data", number: 7, type: .bytes))
        rootMsg.addField(
            FieldDescriptor(
                name: "items",
                number: 8,
                type: .message,
                typeName: "test.Settings",
                isRepeated: true))
        rootMsg.addField(
            FieldDescriptor(
                name: "labels",
                number: 9,
                type: .string,
                isRepeated: true))
        rootMsg.addField(
            FieldDescriptor(
                name: "created_at",
                number: 10,
                type: .message,
                typeName: "google.protobuf.Timestamp"))
        rootMsg.addField(
            FieldDescriptor(
                name: "ttl",
                number: 11,
                type: .message,
                typeName: "google.protobuf.Duration"))
        rootMsg.addField(
            FieldDescriptor(
                name: "timestamps",
                number: 12,
                type: .message,
                typeName: "google.protobuf.Timestamp",
                isRepeated: true))

        var statusEnum = EnumDescriptor(name: "Status", parent: rootMsg)
        statusEnum.addValue(EnumDescriptor.EnumValue(name: "UNKNOWN", number: 0))
        statusEnum.addValue(EnumDescriptor.EnumValue(name: "ACTIVE", number: 1))
        statusEnum.addValue(EnumDescriptor.EnumValue(name: "INACTIVE", number: 2))
        rootMsg.addNestedEnum(statusEnum)

        var settingsMsg = MessageDescriptor(name: "Settings", parent: file)
        settingsMsg.addField(FieldDescriptor(name: "enabled", number: 1, type: .bool))
        settingsMsg.addField(FieldDescriptor(name: "detail", number: 2, type: .message, typeName: "test.Detail"))

        var detailMsg = MessageDescriptor(name: "Detail", parent: file)
        detailMsg.addField(FieldDescriptor(name: "value", number: 1, type: .int64))

        let repo = StubProtoRepository(descriptors: [
            "test.TestRequest": rootMsg,
            "test.Settings": settingsMsg,
            "test.Detail": detailMsg,
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

    // MARK: - Key mode — root message

    func test_keyMode_rootMessage_returnsAllFieldsPlusFillDefaults() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertEqual(suggestions.first?.kind, .fillDefaults)
        let fieldNames = Set(suggestions.dropFirst().map(\.name))
        XCTAssertTrue(fieldNames.contains("name"))
        XCTAssertTrue(fieldNames.contains("count"))
        XCTAssertTrue(fieldNames.contains("settings"))
        XCTAssertTrue(fieldNames.contains("status"))
        XCTAssertTrue(fieldNames.contains("tags"))
    }

    func test_keyMode_rootMessage_fillDefaultsIsAlwaysFirst() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions[0].kind, .fillDefaults)
        XCTAssertEqual(suggestions[0].name, "fillDefaults")
        XCTAssertEqual(suggestions[0].typeHint, "")
    }

    func test_keyMode_rootMessageWithLeadingDot_returnsFields() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: ".test.TestRequest", in: protoFile)

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions.first?.kind, .fillDefaults)
    }

    // MARK: - Key mode — nested message

    func test_keyMode_nestedMessage_returnsNestedFieldsPlusFillDefaults() async {
        let context = AutocompleteContext(resolvedPath: ["settings"], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertEqual(suggestions[0].kind, .fillDefaults)
        let fieldNames = Set(suggestions.dropFirst().map(\.name))
        XCTAssertTrue(fieldNames.contains("enabled"))
        XCTAssertTrue(fieldNames.contains("detail"))
    }

    func test_keyMode_deeplyNestedMessage_returnsDeepFields() async {
        let context = AutocompleteContext(resolvedPath: ["settings", "detail"], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertEqual(suggestions.count, 2)
        XCTAssertEqual(suggestions[0].kind, .fillDefaults)
        XCTAssertEqual(suggestions[1].name, "value")
        XCTAssertEqual(suggestions[1].kind, .number)
    }

    // MARK: - Key mode — error/edge cases

    func test_keyMode_unknownPath_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: ["nonexistent"], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_keyMode_pathToScalarField_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: ["name"], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_keyMode_pathToEnumField_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: ["status"], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_keyMode_unknownRootMessageType_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let repo = StubProtoRepository(descriptors: [:], useFallback: false)
        let provider = ProtoSchemaAutocompleteProvider(protoRepository: repo)

        let suggestions = await provider.suggestions(for: context, rootMessageType: "missing.Type", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_keyMode_emptyMessage_returnsOnlyFillDefaults() async {
        let file = FileDescriptor(name: "e.proto", package: "e")
        let emptyMsg = MessageDescriptor(name: "Empty", parent: file)
        let repo = StubProtoRepository(descriptors: ["e.Empty": emptyMsg])
        let provider = ProtoSchemaAutocompleteProvider(protoRepository: repo)
        let pf = ProtoFile(name: "e.proto", path: URL(fileURLWithPath: "/e.proto"), services: [])

        let context = AutocompleteContext(resolvedPath: [], mode: .key)
        let suggestions = await provider.suggestions(for: context, rootMessageType: "e.Empty", in: pf)

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].kind, .fillDefaults)
    }

    // MARK: - Key mode — field kind mapping

    func test_keyMode_stringField_hasStringKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "name" })
        XCTAssertEqual(field?.kind, .string)
        XCTAssertEqual(field?.typeHint, "string")
    }

    func test_keyMode_int32Field_hasNumberKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "count" })
        XCTAssertEqual(field?.kind, .number)
        XCTAssertEqual(field?.typeHint, "int32")
    }

    func test_keyMode_doubleField_hasNumberKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "score" })
        XCTAssertEqual(field?.kind, .number)
        XCTAssertEqual(field?.typeHint, "double")
    }

    func test_keyMode_bytesField_hasStringKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "data" })
        XCTAssertEqual(field?.kind, .string)
        XCTAssertEqual(field?.typeHint, "bytes")
    }

    func test_keyMode_boolField_hasBoolKind() async {
        let context = AutocompleteContext(resolvedPath: ["settings"], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "enabled" })
        XCTAssertEqual(field?.kind, .bool)
        XCTAssertEqual(field?.typeHint, "bool")
    }

    func test_keyMode_messageField_hasMessageKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "settings" })
        XCTAssertEqual(field?.kind, .message)
        XCTAssertEqual(field?.typeHint, "Settings")
    }

    func test_keyMode_timestampField_hasWktStringKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "created_at" })
        XCTAssertEqual(field?.kind, .wktString, "Timestamp WKT must use wktString kind to re-trigger autocomplete")
        XCTAssertEqual(field?.typeHint, "Timestamp")
    }

    func test_keyMode_durationField_hasWktStringKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "ttl" })
        XCTAssertEqual(field?.kind, .wktString, "Duration WKT must use wktString kind to re-trigger autocomplete")
        XCTAssertEqual(field?.typeHint, "Duration")
    }

    func test_keyMode_repeatedTimestampField_hasRepeatedKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "timestamps" })
        XCTAssertEqual(field?.kind, .repeated)
        XCTAssertEqual(field?.typeHint, "Timestamp[]")
    }

    func test_keyMode_timestampFieldWithLeadingDot_hasWktStringKind() async {
        let file = FileDescriptor(name: "w.proto", package: "w")
        var msg = MessageDescriptor(name: "Req", parent: file)
        msg.addField(FieldDescriptor(name: "ts", number: 1, type: .message, typeName: ".google.protobuf.Timestamp"))

        let repo = StubProtoRepository(descriptors: ["w.Req": msg])
        let provider = ProtoSchemaAutocompleteProvider(protoRepository: repo)
        let pf = ProtoFile(name: "w.proto", path: URL(fileURLWithPath: "/w.proto"), services: [])

        let context = AutocompleteContext(resolvedPath: [], mode: .key)
        let suggestions = await provider.suggestions(for: context, rootMessageType: "w.Req", in: pf)

        let field = suggestions.first(where: { $0.name == "ts" })
        XCTAssertEqual(field?.kind, .wktString, "Leading-dot typeName must be normalised before WKT check")
    }

    func test_arrayElementMode_repeatedTimestampField_returnsWktDefault() async {
        let context = AutocompleteContext(resolvedPath: ["timestamps"], mode: .arrayElement)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertEqual(
            suggestions.count,
            1,
            "Array elements of Timestamp WKT should offer a single WKT default suggestion")
        XCTAssertEqual(suggestions.first?.kind, .wktDefault)
        XCTAssertEqual(suggestions.first?.name, "now")
    }

    func test_keyMode_enumField_hasEnumFieldKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "status" })
        XCTAssertEqual(field?.kind, .enumField)
        XCTAssertEqual(field?.typeHint, "Status")
    }

    func test_keyMode_repeatedEnumField_hasRepeatedKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "tags" })
        XCTAssertEqual(field?.kind, .repeated)
        XCTAssertEqual(field?.typeHint, "Status[]")
    }

    func test_keyMode_repeatedMessageField_hasRepeatedKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "items" })
        XCTAssertEqual(field?.kind, .repeated)
        XCTAssertEqual(field?.typeHint, "Settings[]")
    }

    func test_keyMode_repeatedStringField_hasRepeatedKind() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        let field = suggestions.first(where: { $0.name == "labels" })
        XCTAssertEqual(field?.kind, .repeated)
        XCTAssertEqual(field?.typeHint, "string[]")
    }

    // MARK: - Key mode — oneOf fields

    func test_keyMode_oneOfFields_haveCorrectGroup() async {
        let file = FileDescriptor(name: "o.proto", package: "pkg")
        var msg = MessageDescriptor(name: "Req", parent: file)
        msg.addOneofDecl(OneofDescriptor(name: "choice", index: 0))
        msg.addField(FieldDescriptor(name: "opt_a", number: 1, type: .string, oneofIndex: 0))
        msg.addField(FieldDescriptor(name: "opt_b", number: 2, type: .int32, oneofIndex: 0))
        msg.addField(FieldDescriptor(name: "regular", number: 3, type: .bool))

        let repo = StubProtoRepository(descriptors: ["pkg.Req": msg])
        let provider = ProtoSchemaAutocompleteProvider(protoRepository: repo)
        let pf = ProtoFile(name: "o.proto", path: URL(fileURLWithPath: "/o.proto"), services: [])

        let context = AutocompleteContext(resolvedPath: [], mode: .key)
        let suggestions = await provider.suggestions(for: context, rootMessageType: "pkg.Req", in: pf)

        XCTAssertEqual(suggestions.first(where: { $0.name == "opt_a" })?.oneOfGroup, "choice")
        XCTAssertEqual(suggestions.first(where: { $0.name == "opt_b" })?.oneOfGroup, "choice")
        XCTAssertNil(suggestions.first(where: { $0.name == "regular" })?.oneOfGroup)
    }

    func test_keyMode_nonOneOfFields_haveNilOneOfGroup() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .key)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        for suggestion in suggestions where suggestion.kind != .fillDefaults {
            XCTAssertNil(suggestion.oneOfGroup, "Field '\(suggestion.name)' should have nil oneOfGroup")
        }
    }

    // MARK: - Enum value mode — legacy (path.last = field name)

    func test_enumValueMode_enumField_returnsAllValues() async {
        let context = AutocompleteContext(resolvedPath: ["status"], mode: .enumValue)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertEqual(suggestions.count, 3)
        XCTAssertTrue(suggestions.allSatisfy { $0.kind == .enum })
        let names = Set(suggestions.map(\.name))
        XCTAssertEqual(names, Set(["UNKNOWN", "ACTIVE", "INACTIVE"]))
    }

    func test_enumValueMode_enumField_typeHintIsEnumTypeName() async {
        let context = AutocompleteContext(resolvedPath: ["status"], mode: .enumValue)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.allSatisfy { $0.typeHint == "Status" })
    }

    func test_enumValueMode_nonEnumField_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: ["name"], mode: .enumValue)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_enumValueMode_messageField_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: ["settings"], mode: .enumValue)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_enumValueMode_unknownField_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: ["nonexistent"], mode: .enumValue)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_enumValueMode_emptyPath_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .enumValue)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    // MARK: - Enum value mode — currentFieldKey (resolver-produced context)

    func test_enumValueMode_withCurrentFieldKey_rootLevel_returnsEnumValues() async {
        // Realistic context produced by JsonPathResolver: {"status": |cursor|}
        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "status")

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertEqual(suggestions.count, 3)
        XCTAssertTrue(suggestions.allSatisfy { $0.kind == .enum })
        let names = Set(suggestions.map(\.name))
        XCTAssertEqual(names, Set(["UNKNOWN", "ACTIVE", "INACTIVE"]))
    }

    func test_enumValueMode_withCurrentFieldKey_partialValue_allValuesStillReturned() async {
        // Resolver also sets partialKey when cursor is inside the value string; provider returns all,
        // ViewModel applies the prefix filter. Provider must not filter itself.
        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            partialKey: "ACT",
            currentFieldKey: "status")

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertEqual(suggestions.count, 3, "Provider returns all values; ViewModel applies prefix filter")
    }

    func test_enumValueMode_withCurrentFieldKey_nonEnumField_returnsEmpty() async {
        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "name")

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_enumValueMode_withCurrentFieldKey_unknownField_returnsEmpty() async {
        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "nonexistent")

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_enumValueMode_withCurrentFieldKey_nilKey_emptyPath_returnsEmpty() async {
        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: nil)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_enumValueMode_externalTopLevelEnum_usesRepository() async {
        // Set up a message with a field whose enum type is NOT nested — it lives at top level.
        let file = FileDescriptor(name: "ext.proto", package: "ext")
        var msg = MessageDescriptor(name: "Order", parent: file)
        msg.addField(FieldDescriptor(name: "priority", number: 1, type: .enum, typeName: "ext.Priority"))

        var priorityEnum = EnumDescriptor(name: "Priority", parent: file)
        priorityEnum.addValue(EnumDescriptor.EnumValue(name: "LOW", number: 0))
        priorityEnum.addValue(EnumDescriptor.EnumValue(name: "HIGH", number: 1))

        let repo = StubProtoRepository(
            descriptors: ["ext.Order": msg],
            enumDescriptors: ["ext.Priority": priorityEnum])
        let provider = ProtoSchemaAutocompleteProvider(protoRepository: repo)
        let pf = ProtoFile(name: "ext.proto", path: URL(fileURLWithPath: "/ext.proto"), services: [])

        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "priority")

        let suggestions = await provider.suggestions(for: context, rootMessageType: "ext.Order", in: pf)

        XCTAssertEqual(suggestions.count, 2)
        let names = Set(suggestions.map(\.name))
        XCTAssertEqual(names, Set(["LOW", "HIGH"]))
    }

    func test_arrayElementMode_repeatedExternalEnum_usesRepository() async {
        let file = FileDescriptor(name: "ext2.proto", package: "ext2")
        var msg = MessageDescriptor(name: "Batch", parent: file)
        msg.addField(FieldDescriptor(
            name: "statuses",
            number: 1,
            type: .enum,
            typeName: "ext2.BatchStatus",
            isRepeated: true))

        var batchEnum = EnumDescriptor(name: "BatchStatus", parent: file)
        batchEnum.addValue(EnumDescriptor.EnumValue(name: "PENDING", number: 0))
        batchEnum.addValue(EnumDescriptor.EnumValue(name: "DONE", number: 1))

        let repo = StubProtoRepository(
            descriptors: ["ext2.Batch": msg],
            enumDescriptors: ["ext2.BatchStatus": batchEnum])
        let provider = ProtoSchemaAutocompleteProvider(protoRepository: repo)
        let pf = ProtoFile(name: "ext2.proto", path: URL(fileURLWithPath: "/ext2.proto"), services: [])

        let context = AutocompleteContext(resolvedPath: ["statuses"], mode: .arrayElement)

        let suggestions = await provider.suggestions(for: context, rootMessageType: "ext2.Batch", in: pf)

        XCTAssertEqual(suggestions.count, 2)
        XCTAssertTrue(suggestions.allSatisfy { $0.kind == .enum })
        let names = Set(suggestions.map(\.name))
        XCTAssertEqual(names, Set(["PENDING", "DONE"]))
    }

    // MARK: - Array element mode

    func test_arrayElementMode_repeatedEnumField_returnsEnumValues() async {
        let context = AutocompleteContext(resolvedPath: ["tags"], mode: .arrayElement)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertEqual(suggestions.count, 3)
        XCTAssertTrue(suggestions.allSatisfy { $0.kind == .enum })
    }

    func test_arrayElementMode_repeatedMessageField_returnsFieldsPlusFillDefaults() async {
        let context = AutocompleteContext(resolvedPath: ["items"], mode: .arrayElement)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertEqual(suggestions[0].kind, .fillDefaults)
        let fieldNames = Set(suggestions.dropFirst().map(\.name))
        XCTAssertTrue(fieldNames.contains("enabled"))
    }

    func test_arrayElementMode_repeatedScalarField_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: ["labels"], mode: .arrayElement)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_arrayElementMode_nonRepeatedField_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: ["name"], mode: .arrayElement)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_arrayElementMode_emptyPath_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: [], mode: .arrayElement)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    func test_arrayElementMode_unknownField_returnsEmpty() async {
        let context = AutocompleteContext(resolvedPath: ["nonexistent"], mode: .arrayElement)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }

    // MARK: - All scalar type hints

    func test_typeHint_allNumericTypes_mapCorrectly() async {
        let file = FileDescriptor(name: "n.proto", package: "n")
        var msg = MessageDescriptor(name: "Numbers", parent: file)
        msg.addField(FieldDescriptor(name: "f_double", number: 1, type: .double))
        msg.addField(FieldDescriptor(name: "f_float", number: 2, type: .float))
        msg.addField(FieldDescriptor(name: "f_int32", number: 3, type: .int32))
        msg.addField(FieldDescriptor(name: "f_int64", number: 4, type: .int64))
        msg.addField(FieldDescriptor(name: "f_uint32", number: 5, type: .uint32))
        msg.addField(FieldDescriptor(name: "f_uint64", number: 6, type: .uint64))
        msg.addField(FieldDescriptor(name: "f_sint32", number: 7, type: .sint32))
        msg.addField(FieldDescriptor(name: "f_sint64", number: 8, type: .sint64))
        msg.addField(FieldDescriptor(name: "f_fixed32", number: 9, type: .fixed32))
        msg.addField(FieldDescriptor(name: "f_fixed64", number: 10, type: .fixed64))
        msg.addField(FieldDescriptor(name: "f_sfixed32", number: 11, type: .sfixed32))
        msg.addField(FieldDescriptor(name: "f_sfixed64", number: 12, type: .sfixed64))

        let repo = StubProtoRepository(descriptors: ["n.Numbers": msg])
        let provider = ProtoSchemaAutocompleteProvider(protoRepository: repo)
        let pf = ProtoFile(name: "n.proto", path: URL(fileURLWithPath: "/n.proto"), services: [])

        let context = AutocompleteContext(resolvedPath: [], mode: .key)
        let suggestions = await provider.suggestions(for: context, rootMessageType: "n.Numbers", in: pf)

        let lookup = Dictionary(uniqueKeysWithValues: suggestions.map { ($0.name, $0) })

        XCTAssertEqual(lookup["f_double"]?.typeHint, "double")
        XCTAssertEqual(lookup["f_float"]?.typeHint, "float")
        XCTAssertEqual(lookup["f_int32"]?.typeHint, "int32")
        XCTAssertEqual(lookup["f_int64"]?.typeHint, "int64")
        XCTAssertEqual(lookup["f_uint32"]?.typeHint, "uint32")
        XCTAssertEqual(lookup["f_uint64"]?.typeHint, "uint64")
        XCTAssertEqual(lookup["f_sint32"]?.typeHint, "int32")
        XCTAssertEqual(lookup["f_sint64"]?.typeHint, "int64")
        XCTAssertEqual(lookup["f_fixed32"]?.typeHint, "uint32")
        XCTAssertEqual(lookup["f_fixed64"]?.typeHint, "uint64")
        XCTAssertEqual(lookup["f_sfixed32"]?.typeHint, "int32")
        XCTAssertEqual(lookup["f_sfixed64"]?.typeHint, "int64")

        for name in lookup.keys where name != "fillDefaults" {
            XCTAssertEqual(lookup[name]?.kind, .number, "\(name) should be .number")
        }
    }

    // MARK: - WKT default value suggestions

    func test_enumValueMode_timestampField_returnsNowSuggestion() async throws {
        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "created_at")

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertEqual(suggestions.count, 1)
        let s = try XCTUnwrap(suggestions.first)
        XCTAssertEqual(s.kind, .wktDefault)
        XCTAssertEqual(s.name, "now")
        XCTAssertEqual(s.typeHint, "Timestamp RFC 3339")
        XCTAssertFalse(s.insertValue?.isEmpty ?? true)
    }

    func test_enumValueMode_timestampField_insertValueIsCurrentRFC3339() async throws {
        let before = Date()
        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "created_at")

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)
        let after = Date()

        let s = try XCTUnwrap(suggestions.first)
        let insertedStr = try XCTUnwrap(s.insertValue)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let parsed = try XCTUnwrap(formatter.date(from: insertedStr))
        XCTAssertGreaterThanOrEqual(parsed, before.addingTimeInterval(-1))
        XCTAssertLessThanOrEqual(parsed, after.addingTimeInterval(1))
    }

    func test_enumValueMode_durationField_returnsMultipleSuggestions() async {
        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "ttl")

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertGreaterThan(suggestions.count, 1, "Duration should offer multiple unit suggestions")
        XCTAssertTrue(suggestions.allSatisfy { $0.kind == .wktDefault })
    }

    func test_enumValueMode_durationField_containsCommonUnits() async {
        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "ttl")

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)
        let names = Set(suggestions.map(\.name))

        XCTAssertTrue(names.contains("0s"))
        XCTAssertTrue(names.contains("1s"))
        XCTAssertTrue(names.contains("60s"))
        XCTAssertTrue(names.contains("3600s"))
        XCTAssertTrue(names.contains("86400s"))
    }

    func test_arrayElementMode_repeatedTimestampField_returnsNowSuggestion() async {
        let context = AutocompleteContext(resolvedPath: ["timestamps"], mode: .arrayElement)

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.kind, .wktDefault)
        XCTAssertEqual(suggestions.first?.name, "now")
    }

    func test_enumValueMode_regularStringField_returnsEmpty() async {
        let context = AutocompleteContext(
            resolvedPath: [],
            mode: .enumValue,
            currentFieldKey: "name")

        let suggestions = await sut.suggestions(for: context, rootMessageType: "test.TestRequest", in: protoFile)

        XCTAssertTrue(suggestions.isEmpty)
    }
}
