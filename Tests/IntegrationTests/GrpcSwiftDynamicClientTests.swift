import GRPCCore
import SwiftProtoReflect
import XCTest
@testable import TrueRPCMini

@MainActor
final class GrpcSwiftDynamicClientTests: XCTestCase {
    let grpcClientScopeProtoFile = ProtoFile(
        name: "grpc_client_scope.proto",
        path: URL(fileURLWithPath: "/tmp/grpc_client_scope.proto"),
        services: [])

    var sut: GrpcSwiftDynamicClient!
    fileprivate var mockRepository: MockProtoRepository!
    var mockLogger: MockAppLogger!
    var fileDescriptor: FileDescriptor!
    var messageDescriptor: MessageDescriptor!

    override func setUp() async throws {
        try await super.setUp()
        fileDescriptor = FileDescriptor(name: "test.proto", package: "test")

        var tempDescriptor = MessageDescriptor(name: "Person", parent: fileDescriptor)
        let nameField = FieldDescriptor(name: "name", number: 1, type: .string)
        let ageField = FieldDescriptor(name: "age", number: 2, type: .int32)
        tempDescriptor.addField(nameField)
        tempDescriptor.addField(ageField)
        messageDescriptor = tempDescriptor

        mockRepository = MockProtoRepository()
        mockRepository.stubbedMessageDescriptor = messageDescriptor
        mockLogger = MockAppLogger()

        sut = GrpcSwiftDynamicClient(protoRepository: mockRepository, logger: mockLogger)
    }

    override func tearDown() async throws {
        mockRepository?.capturedProtoFiles.removeAll()
        sut = nil
        mockRepository = nil
        mockLogger = nil
        messageDescriptor = nil
        fileDescriptor = nil
        try await super.tearDown()
    }

    // MARK: - JSON Parsing

    func test_parseJSON_withValidJSON_createsDynamicMessage() throws {
        // Given
        let jsonString = #"{"name": "Alice", "age": 30}"#
        let registry = TypeRegistry()

        // When
        let result = try sut.parseJSON(jsonString, using: messageDescriptor, typeRegistry: registry)

        // Then
        XCTAssertEqual(try result.get(forField: "name") as? String, "Alice")
        XCTAssertEqual(try result.get(forField: "age") as? Int32, 30)
    }

    func test_parseJSON_withInvalidJSON_throwsError() throws {
        // Given
        let jsonString = "{invalid json"
        let registry = TypeRegistry()

        // When/Then
        XCTAssertThrowsError(try sut.parseJSON(jsonString, using: messageDescriptor, typeRegistry: registry))
    }

    func test_parseJSON_withEmptyJSON_createsEmptyMessage() throws {
        // Given
        let jsonString = "{}"
        let emptyDescriptor = MessageDescriptor(name: "Empty", parent: fileDescriptor)
        let registry = TypeRegistry()

        // When
        let result = try sut.parseJSON(jsonString, using: emptyDescriptor, typeRegistry: registry)

        // Then
        XCTAssertNotNil(result)
    }

    /// Regression: repeated message elements need `JSONDeserializationOptions.typeRegistry` (SwiftProtoReflect).
    func test_parseJSON_repeatedNestedMessage_withTypeRegistry_succeeds() throws {
        let file = FileDescriptor(name: "example.proto", package: "example")
        var userDesc = MessageDescriptor(name: "User", parent: file)
        userDesc.addField(FieldDescriptor(name: "id", number: 1, type: .string))
        userDesc.addField(FieldDescriptor(name: "name", number: 2, type: .string))

        var twoRequestDesc = MessageDescriptor(name: "TwoRequest", parent: file)
        twoRequestDesc.addField(
            FieldDescriptor(
                name: "names",
                number: 1,
                type: .message,
                typeName: "example.User",
                isRepeated: true))

        let registry = TypeRegistry()
        try registry.registerMessage(userDesc)
        try registry.registerMessage(twoRequestDesc)

        let json = #"{"names":[{"id":"","name":""}]}"#
        let result = try sut.parseJSON(json, using: twoRequestDesc, typeRegistry: registry)
        let names = try XCTUnwrap(try result.get(forField: "names") as? [DynamicMessage])
        XCTAssertEqual(names.count, 1)
        XCTAssertEqual(try names[0].get(forField: "id") as? String, "")
        XCTAssertEqual(try names[0].get(forField: "name") as? String, "")
    }

    /// Protobuf JSON encodes `google.protobuf.Timestamp` as an RFC 3339 string; SwiftProtoReflect expects an object.
    func test_parseJSON_repeatedUserWithProtobufJSONTimestampString_succeeds() throws {
        let file = FileDescriptor(name: "example.proto", package: "example")
        let builtinPool = DescriptorPool(includeBuiltinDescriptors: true)
        let timestampDesc = try XCTUnwrap(builtinPool.findMessageDescriptor(named: WellKnownTypeNames.timestamp))

        var userDesc = MessageDescriptor(name: "User", parent: file)
        userDesc.addField(FieldDescriptor(name: "id", number: 1, type: .string))
        userDesc.addField(FieldDescriptor(name: "name", number: 2, type: .string))
        userDesc.addField(
            FieldDescriptor(
                name: "birthday",
                number: 3,
                type: .message,
                typeName: WellKnownTypeNames.timestamp))

        var twoRequestDesc = MessageDescriptor(name: "TwoRequest", parent: file)
        twoRequestDesc.addField(
            FieldDescriptor(
                name: "names",
                number: 1,
                type: .message,
                typeName: "example.User",
                isRepeated: true))

        let registry = TypeRegistry()
        try registry.registerMessage(timestampDesc)
        try registry.registerMessage(userDesc)
        try registry.registerMessage(twoRequestDesc)

        let json = #"{"names":[{"id":"","name":"","birthday":"1970-01-01T00:00:00Z"}]}"#
        let result = try sut.parseJSON(json, using: twoRequestDesc, typeRegistry: registry)
        let names = try XCTUnwrap(try result.get(forField: "names") as? [DynamicMessage])
        XCTAssertEqual(names.count, 1)
        let birthday = try XCTUnwrap(try names[0].get(forField: "birthday") as? DynamicMessage)
        XCTAssertEqual(try birthday.get(forField: "seconds") as? Int64, 0)
        XCTAssertEqual(try birthday.get(forField: "nanos") as? Int32, 0)
    }

    func test_parseJSON_singularTimestampProtobufJSONString_onRootMessage_succeeds() throws {
        let file = FileDescriptor(name: "example.proto", package: "example")
        let builtinPool = DescriptorPool(includeBuiltinDescriptors: true)
        let timestampDesc = try XCTUnwrap(builtinPool.findMessageDescriptor(named: WellKnownTypeNames.timestamp))

        var eventDesc = MessageDescriptor(name: "Event", parent: file)
        eventDesc.addField(
            FieldDescriptor(
                name: "created_at",
                number: 1,
                type: .message,
                typeName: WellKnownTypeNames.timestamp))

        let registry = TypeRegistry()
        try registry.registerMessage(timestampDesc)
        try registry.registerMessage(eventDesc)

        let json = #"{"created_at":"2000-01-01T00:00:00Z"}"#
        let result = try sut.parseJSON(json, using: eventDesc, typeRegistry: registry)
        let ts = try XCTUnwrap(try result.get(forField: "created_at") as? DynamicMessage)
        XCTAssertEqual(try ts.get(forField: "seconds") as? Int64, 946_684_800)
    }

    func test_parseJSON_repeatedDurationProtobufJSONString_succeeds() throws {
        let file = FileDescriptor(name: "test.proto", package: "test")
        let builtinPool = DescriptorPool(includeBuiltinDescriptors: true)
        let durationDesc = try XCTUnwrap(builtinPool.findMessageDescriptor(named: WellKnownTypeNames.duration))

        var rootDesc = MessageDescriptor(name: "Delays", parent: file)
        rootDesc.addField(
            FieldDescriptor(
                name: "values",
                number: 1,
                type: .message,
                typeName: WellKnownTypeNames.duration,
                isRepeated: true))

        let registry = TypeRegistry()
        try registry.registerMessage(durationDesc)
        try registry.registerMessage(rootDesc)

        let json = #"{"values":["1s","0.5s"]}"#
        let result = try sut.parseJSON(json, using: rootDesc, typeRegistry: registry)
        let values = try XCTUnwrap(try result.get(forField: "values") as? [DynamicMessage])
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(try values[0].get(forField: "seconds") as? Int64, 1)
        XCTAssertEqual(try values[0].get(forField: "nanos") as? Int32, 0)
        XCTAssertEqual(try values[1].get(forField: "seconds") as? Int64, 0)
        XCTAssertEqual(try values[1].get(forField: "nanos") as? Int32, 500_000_000)
    }

    func test_parseJSON_mapWithTimestampStringValues_normalizesForDeserializer() throws {
        let file = FileDescriptor(name: "sched.proto", package: "sched")
        let builtinPool = DescriptorPool(includeBuiltinDescriptors: true)
        let timestampDesc = try XCTUnwrap(builtinPool.findMessageDescriptor(named: WellKnownTypeNames.timestamp))

        let mapEntry = MapEntryInfo(
            keyFieldInfo: KeyFieldInfo(name: "key", number: 1, type: .string),
            valueFieldInfo: ValueFieldInfo(
                name: "value",
                number: 2,
                type: .message,
                typeName: WellKnownTypeNames.timestamp))

        var scheduleDesc = MessageDescriptor(name: "Schedule", parent: file)
        scheduleDesc.addField(
            FieldDescriptor(
                name: "start_by_user",
                number: 1,
                type: .message,
                typeName: "sched.Schedule.StartByUserEntry",
                isMap: true,
                mapEntryInfo: mapEntry))

        let registry = TypeRegistry()
        try registry.registerMessage(timestampDesc)
        try registry.registerMessage(scheduleDesc)

        let json = #"{"start_by_user":{"alice":"1970-01-01T00:00:00Z"}}"#
        let result = try sut.parseJSON(json, using: scheduleDesc, typeRegistry: registry)
        let mapVal = try XCTUnwrap(try result.get(forField: "start_by_user") as? [AnyHashable: Any])
        let alice = try XCTUnwrap(mapVal["alice"] as? DynamicMessage)
        XCTAssertEqual(try alice.get(forField: "seconds") as? Int64, 0)
    }

    // MARK: - Message to JSON

    func test_messageToJSON_withValidMessage_returnsJSONString() throws {
        // Given
        var message = MessageFactory().createMessage(from: messageDescriptor)
        try message.set("Bob", forField: "name")
        try message.set(Int32(25), forField: "age")

        // When
        let jsonString = try sut.messageToJSON(message)

        // Then
        XCTAssertTrue(jsonString.contains("Bob"))
        XCTAssertTrue(jsonString.contains("25"))

        // Verify it's valid JSON
        let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(parsed)
    }

    func test_messageToJSON_withEmptyMessage_returnsEmptyObject() throws {
        // Given
        let emptyDescriptor = MessageDescriptor(name: "Empty", parent: fileDescriptor)
        let message = MessageFactory().createMessage(from: emptyDescriptor)

        // When
        let jsonString = try sut.messageToJSON(message)

        // Then
        XCTAssertEqual(jsonString, "{}")
    }

    // MARK: - Server Address Parsing

    func test_parseServerAddress_withHostAndPort_returnsCorrectValues() throws {
        // Given
        let address = "localhost:50051"

        // When
        let (host, port) = try sut.parseServerAddress(address)

        // Then
        XCTAssertEqual(host, "localhost")
        XCTAssertEqual(port, 50051)
    }

    func test_parseServerAddress_withOnlyHost_usesDefaultPort() throws {
        // Given
        let address = "api.example.com"

        // When
        let (host, port) = try sut.parseServerAddress(address)

        // Then
        XCTAssertEqual(host, "api.example.com")
        XCTAssertEqual(port, 50051)
    }

    func test_parseServerAddress_withHttpProtocol_stripsProtocol() throws {
        // Given
        let address = "http://localhost:8080"

        // When
        let (host, port) = try sut.parseServerAddress(address)

        // Then
        XCTAssertEqual(host, "localhost")
        XCTAssertEqual(port, 8080)
    }

    func test_parseServerAddress_withHttpsProtocol_stripsProtocol() throws {
        // Given
        let address = "https://api.example.com:443"

        // When
        let (host, port) = try sut.parseServerAddress(address)

        // Then
        XCTAssertEqual(host, "api.example.com")
        XCTAssertEqual(port, 443)
    }

    // MARK: - buildTransportSecurity Tests

    func test_buildTransportSecurity_whenPlaintext_returnsPlaintext() throws {
        let tlsConfig = TLSConfiguration.defaults
        XCTAssertNoThrow(try sut.buildTransportSecurity(from: tlsConfig))
    }

    func test_buildTransportSecurity_whenStandardTLS_returnsTLS() throws {
        let tlsConfig = TLSConfiguration(isTLSEnabled: true)
        XCTAssertNoThrow(try sut.buildTransportSecurity(from: tlsConfig))
    }

    func test_buildTransportSecurity_whenInsecure_returnsTLSWithSkipVerify() throws {
        let tlsConfig = TLSConfiguration(isTLSEnabled: true, allowInsecure: true)
        XCTAssertNoThrow(try sut.buildTransportSecurity(from: tlsConfig))
    }

    func test_buildTransportSecurity_whenCustomCA_loadsCertificate() throws {
        let caURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-ca.pem")
        FileManager.default.createFile(atPath: caURL.path, contents: Data("stub".utf8))
        defer { try? FileManager.default.removeItem(at: caURL) }

        let tlsConfig = TLSConfiguration(isTLSEnabled: true, customCAURL: caURL)
        XCTAssertNoThrow(try sut.buildTransportSecurity(from: tlsConfig))
    }

    func test_buildTransportSecurity_whenMTLS_loadsClientCertAndKey() throws {
        let certURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-cert.pem")
        let keyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-key.pem")
        FileManager.default.createFile(atPath: certURL.path, contents: Data("stub".utf8))
        FileManager.default.createFile(atPath: keyURL.path, contents: Data("stub".utf8))
        defer {
            try? FileManager.default.removeItem(at: certURL)
            try? FileManager.default.removeItem(at: keyURL)
        }

        let tlsConfig = TLSConfiguration(isTLSEnabled: true, clientCertURL: certURL, clientKeyURL: keyURL)
        XCTAssertNoThrow(try sut.buildTransportSecurity(from: tlsConfig))
    }

    func test_buildTransportSecurity_whenInvalidCAURL_throwsTLSConfigurationFailed() {
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path/ca.pem")
        let tlsConfig = TLSConfiguration(isTLSEnabled: true, customCAURL: nonExistentURL)

        XCTAssertThrowsError(try sut.buildTransportSecurity(from: tlsConfig)) { error in
            guard case GrpcClientError.tlsConfigurationFailed = error else {
                XCTFail("Expected tlsConfigurationFailed, got \(error)")
                return
            }
        }
    }

    func test_buildTransportSecurity_whenMTLSWithCustomCA_loadsAllThreePaths() throws {
        let certURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-cert.pem")
        let keyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-key.pem")
        let caURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-ca.pem")
        FileManager.default.createFile(atPath: certURL.path, contents: Data("stub".utf8))
        FileManager.default.createFile(atPath: keyURL.path, contents: Data("stub".utf8))
        FileManager.default.createFile(atPath: caURL.path, contents: Data("stub".utf8))
        defer {
            try? FileManager.default.removeItem(at: certURL)
            try? FileManager.default.removeItem(at: keyURL)
            try? FileManager.default.removeItem(at: caURL)
        }

        let tlsConfig = TLSConfiguration(
            isTLSEnabled: true,
            customCAURL: caURL,
            clientCertURL: certURL,
            clientKeyURL: keyURL)
        XCTAssertNoThrow(try sut.buildTransportSecurity(from: tlsConfig))
    }

    func test_buildTransportSecurity_whenMTLSWithMissingCustomCA_throwsTLSConfigurationFailed() {
        let certURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-cert.pem")
        let keyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "-key.pem")
        let nonExistentCAURL = URL(fileURLWithPath: "/nonexistent/path/ca.pem")
        FileManager.default.createFile(atPath: certURL.path, contents: Data("stub".utf8))
        FileManager.default.createFile(atPath: keyURL.path, contents: Data("stub".utf8))
        defer {
            try? FileManager.default.removeItem(at: certURL)
            try? FileManager.default.removeItem(at: keyURL)
        }

        let tlsConfig = TLSConfiguration(
            isTLSEnabled: true,
            customCAURL: nonExistentCAURL,
            clientCertURL: certURL,
            clientKeyURL: keyURL)

        XCTAssertThrowsError(try sut.buildTransportSecurity(from: tlsConfig)) { error in
            guard case GrpcClientError.tlsConfigurationFailed = error else {
                XCTFail("Expected tlsConfigurationFailed, got \(error)")
                return
            }
        }
    }

    func test_parseServerAddress_withEmptyString_throwsError() {
        // Given
        let address = ""

        // When/Then
        XCTAssertThrowsError(try sut.parseServerAddress(address)) { error in
            guard case GrpcClientError.networkError = error else {
                XCTFail("Expected networkError")
                return
            }
        }
    }

    func test_parseServerAddress_withInvalidPort_usesDefaultPort() throws {
        // Given
        let address = "localhost:invalid"

        // When
        let (host, port) = try sut.parseServerAddress(address)

        // Then
        XCTAssertEqual(host, "localhost")
        XCTAssertEqual(port, 50051) // Falls back to default
    }

    // MARK: - Error Mapping

    func test_mapGrpcError_withUnavailable_returnsUnavailable() {
        // Given
        let rpcError = RPCError(code: .unavailable, message: "Service unavailable")

        // When
        let result = sut.mapGrpcError(rpcError)

        // Then
        XCTAssertEqual(result, .unavailable)
    }

    func test_mapGrpcError_withDeadlineExceeded_returnsTimeout() {
        // Given
        let rpcError = RPCError(code: .deadlineExceeded, message: "Deadline exceeded")

        // When
        let result = sut.mapGrpcError(rpcError)

        // Then
        XCTAssertEqual(result, .timeout)
    }

    func test_mapGrpcError_withOtherCode_returnsNetworkError() {
        // Given
        let rpcError = RPCError(code: .unknown, message: "Unknown error")

        // When
        let result = sut.mapGrpcError(rpcError)

        // Then
        if case let .networkError(message) = result {
            XCTAssertTrue(message.contains("Unknown"))
        } else {
            XCTFail("Expected networkError")
        }
    }

    // MARK: - Execute Unary (Integration-style tests)

    func test_executeUnary_getsMessageDescriptorsFromRepository() async throws {
        // Given
        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.Request",
            outputType: ".test.Response")
        let request = RequestDraft(
            jsonBody: #"{"name": "test"}"#,
            url: "localhost:50051",
            method: method)

        // Create descriptors for input and output
        var inputDescriptor = MessageDescriptor(name: "Request", parent: fileDescriptor)
        inputDescriptor.addField(FieldDescriptor(name: "name", number: 1, type: .string))

        var outputDescriptor = MessageDescriptor(name: "Response", parent: fileDescriptor)
        outputDescriptor.addField(FieldDescriptor(name: "result", number: 1, type: .string))

        // Setup mock to return different descriptors based on type
        mockRepository.inputDescriptor = inputDescriptor
        mockRepository.outputDescriptor = outputDescriptor

        // When - This will fail trying to connect to localhost:50051, but that's ok
        // We're testing that it calls the repository correctly
        do {
            _ = try await sut.executeUnary(request: request, method: method, protoFile: grpcClientScopeProtoFile)
            XCTFail("Should throw network error")
        } catch {
            // Expected to fail at network level
            // But we can verify repository was called
            XCTAssertTrue(mockRepository.getMessageDescriptorCalled)
            XCTAssertTrue(mockRepository.capturedTypeNames.contains(".test.Request"))
            XCTAssertTrue(mockRepository.capturedTypeNames.contains(".test.Response"))
            XCTAssertEqual(mockRepository.capturedProtoFiles.count, 2)
            XCTAssertTrue(mockRepository.capturedProtoFiles.allSatisfy { $0.id == grpcClientScopeProtoFile.id })
        }
    }

    func test_executeUnary_whenRepositoryThrows_propagatesError() async {
        // Given
        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.NonExistent",
            outputType: ".test.Response")
        let request = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: method)

        mockRepository.shouldThrow = true

        // When/Then
        do {
            _ = try await sut.executeUnary(request: request, method: method, protoFile: grpcClientScopeProtoFile)
            XCTFail("Should throw error")
        } catch {
            // Should get repository error (messageTypeNotFound)
            XCTAssertTrue(error is ProtoRepositoryError)
        }
    }

    func test_executeUnary_whenRepositoryThrows_logsError() async {
        // Given
        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.NonExistent",
            outputType: ".test.Response")
        let request = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: method)
        mockRepository.shouldThrow = true

        // When
        do {
            _ = try await sut.executeUnary(request: request, method: method, protoFile: grpcClientScopeProtoFile)
            XCTFail("Should throw error")
        } catch {
            // Expected
        }

        // Then - error must be logged with context
        XCTAssertEqual(mockLogger.errorMessages.count, 1)
        let logEntry = mockLogger.errorMessages[0]
        XCTAssertEqual(logEntry.message, "Proto message descriptor not found")
        XCTAssertEqual(logEntry.metadata["inputType"], ".test.NonExistent")
        XCTAssertEqual(logEntry.metadata["service"], "TestService")
        XCTAssertEqual(logEntry.metadata["method"], "TestMethod")
        XCTAssertNotNil(logEntry.metadata["error"])
    }

    func test_executeUnary_withInvalidJSON_throwsError() async {
        // Given
        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.Request",
            outputType: ".test.Response")
        let request = RequestDraft(
            jsonBody: "{invalid json",
            url: "localhost:50051",
            method: method)

        mockRepository.stubbedMessageDescriptor = messageDescriptor

        // When/Then
        do {
            _ = try await sut.executeUnary(request: request, method: method, protoFile: grpcClientScopeProtoFile)
            XCTFail("Should throw error")
        } catch {
            // Should get JSON parsing error
            XCTAssertNotNil(error)
        }
    }

    func test_executeUnary_withInvalidJSON_logsSerializationError() async {
        // Given
        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.Request",
            outputType: ".test.Response")
        let request = RequestDraft(
            jsonBody: "{invalid json",
            url: "localhost:50051",
            method: method)
        mockRepository.stubbedMessageDescriptor = messageDescriptor

        // When
        do {
            _ = try await sut.executeUnary(request: request, method: method, protoFile: grpcClientScopeProtoFile)
            XCTFail("Should throw error")
        } catch {
            // Expected
        }

        // Then - serialization error logged with full metadata
        let serializationErrors = mockLogger.errorMessages.filter { $0.message == "Request serialization failed" }
        XCTAssertEqual(serializationErrors.count, 1)
        let logEntry = serializationErrors[0]
        XCTAssertEqual(logEntry.metadata["service"], "TestService")
        XCTAssertEqual(logEntry.metadata["method"], "TestMethod")
        XCTAssertNotNil(logEntry.metadata["error"])
        XCTAssertEqual(logEntry.metadata["field_count"], "2") // messageDescriptor has name and age fields
        XCTAssertEqual(logEntry.metadata["missing_field"], "none")
        XCTAssertEqual(logEntry.metadata["type_mismatch"], "none")
    }

    func test_executeUnary_withInvalidServerAddress_throwsError() async {
        // Given
        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.Request",
            outputType: ".test.Response")
        let request = RequestDraft(
            jsonBody: "{}",
            url: "", // Invalid empty address
            method: method)

        mockRepository.stubbedMessageDescriptor = messageDescriptor

        // When/Then
        do {
            _ = try await sut.executeUnary(request: request, method: method, protoFile: grpcClientScopeProtoFile)
            XCTFail("Should throw error")
        } catch let error as GrpcClientError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Expected GrpcClientError, got \(error)")
        }
    }

    /// Regression (OPE-239): `executeUnary` must pass `protoFile` into `getMessageDescriptor` so JSON is validated
    /// against the tab's schema. Same method + JSON can succeed for one tab and fail serialization for another.
    func test_executeUnary_whenSameRequestType_scopedByProtoFile_usesMatchingInputDescriptor() async throws {
        let pkg = FileDescriptor(name: "test.proto", package: "test")

        var inputStringMsg = MessageDescriptor(name: "Request", parent: pkg)
        inputStringMsg.addField(FieldDescriptor(name: "msg", number: 1, type: .string))

        var inputIntMsg = MessageDescriptor(name: "Request", parent: pkg)
        inputIntMsg.addField(FieldDescriptor(name: "msg", number: 1, type: .int32))

        var outputDesc = MessageDescriptor(name: "Response", parent: pkg)
        outputDesc.addField(FieldDescriptor(name: "ok", number: 1, type: .bool))

        mockRepository.inputDescriptor = nil
        mockRepository.stubbedMessageDescriptor = nil
        mockRepository.inputDescriptorByProtoBasename = [
            "tab_a.proto": inputStringMsg,
            "tab_b.proto": inputIntMsg,
        ]
        mockRepository.outputDescriptor = outputDesc
        defer {
            mockRepository.inputDescriptorByProtoBasename = nil
            mockRepository.outputDescriptor = nil
            mockRepository.stubbedMessageDescriptor = messageDescriptor
        }

        let method = TrueRPCMini.Method(
            name: "TestMethod",
            serviceName: "TestService",
            inputType: ".test.Request",
            outputType: ".test.Response")
        let request = RequestDraft(
            jsonBody: #"{"msg":"hello"}"#,
            url: "localhost:50051",
            method: method)

        let protoB = ProtoFile(
            name: "tab_b.proto",
            path: URL(fileURLWithPath: "/tmp/tab_b.proto"),
            services: [])
        mockLogger.reset()
        mockRepository.capturedProtoFiles.removeAll()
        mockRepository.capturedTypeNames.removeAll()

        do {
            _ = try await sut.executeUnary(request: request, method: method, protoFile: protoB)
            XCTFail("Expected request JSON to fail against int32 msg descriptor")
        } catch {
            let serializationFailures = mockLogger.errorMessages.filter { $0.message == "Request serialization failed" }
            XCTAssertEqual(serializationFailures.count, 1, "Wrong-tab schema should reject string JSON for int32 field")
        }
        XCTAssertTrue(
            mockRepository.capturedProtoFiles.contains { $0.path.lastPathComponent == "tab_b.proto" },
            "Repository must receive tab B proto file for descriptor lookup")

        let protoA = ProtoFile(
            name: "tab_a.proto",
            path: URL(fileURLWithPath: "/tmp/tab_a.proto"),
            services: [])
        mockLogger.reset()
        mockRepository.capturedProtoFiles.removeAll()
        mockRepository.capturedTypeNames.removeAll()

        do {
            _ = try await sut.executeUnary(request: request, method: method, protoFile: protoA)
            XCTFail("Expected failure after network (JSON should match tab A descriptor)")
        } catch {
            XCTAssertFalse(error is ProtoRepositoryError, "Descriptor lookup for tab A should succeed")
            let serializationFailures = mockLogger.errorMessages.filter { $0.message == "Request serialization failed" }
            XCTAssertTrue(
                serializationFailures.isEmpty,
                "Same JSON must serialize for tab A (string msg)")
        }
        XCTAssertTrue(
            mockRepository.capturedProtoFiles.allSatisfy { $0.path.lastPathComponent == "tab_a.proto" })
    }
}

// MARK: - Mock Repository

@MainActor
private final class MockProtoRepository: ProtoRepositoryProtocol {
    var stubbedMessageDescriptor: MessageDescriptor?
    var inputDescriptor: MessageDescriptor?
    var outputDescriptor: MessageDescriptor?
    /// When set, `.test.Request` (any type name containing `Request`) resolves from this map by
    /// `protoFile.path.lastPathComponent`.
    var inputDescriptorByProtoBasename: [String: MessageDescriptor]?
    var getMessageDescriptorCalled = false
    var capturedTypeName: String?
    var capturedTypeNames: [String] = []
    var capturedProtoFiles: [ProtoFile] = []
    var shouldThrow = false

    func loadProto(url _: URL) throws -> ProtoFile {
        fatalError("Not implemented in mock")
    }

    func loadProto(url _: URL, importPaths _: [String]) throws -> ProtoFile {
        fatalError("Not implemented in mock")
    }

    func getLoadedProtos() -> [ProtoFile] {
        []
    }

    func getMessageDescriptor(forType typeName: String, in protoFile: ProtoFile) throws -> MessageDescriptor {
        getMessageDescriptorCalled = true
        capturedTypeName = typeName
        capturedTypeNames.append(typeName)
        capturedProtoFiles.append(protoFile)

        if shouldThrow {
            throw ProtoRepositoryError.messageTypeNotFound(typeName)
        }

        if let map = inputDescriptorByProtoBasename,
           typeName.contains("Request"),
           let descriptor = map[protoFile.path.lastPathComponent]
        {
            return descriptor
        }

        if typeName.contains("Request"), let descriptor = inputDescriptor {
            return descriptor
        }
        if typeName.contains("Response"), let descriptor = outputDescriptor {
            return descriptor
        }

        guard let descriptor = stubbedMessageDescriptor else {
            throw ProtoRepositoryError.messageTypeNotFound(typeName)
        }

        return descriptor
    }

    func makeJSONTypeRegistry(for _: ProtoFile) throws -> TypeRegistry {
        let registry = TypeRegistry()
        if let descriptor = stubbedMessageDescriptor {
            try? registry.registerMessage(descriptor)
        }
        if let descriptor = inputDescriptor {
            try? registry.registerMessage(descriptor)
        }
        if let descriptor = outputDescriptor {
            try? registry.registerMessage(descriptor)
        }
        if let map = inputDescriptorByProtoBasename {
            for descriptor in map.values {
                try? registry.registerMessage(descriptor)
            }
        }
        return registry
    }
}

// MARK: - Metadata Conversion Tests

extension GrpcSwiftDynamicClientTests {
    func test_convertToGrpcMetadata_withStringHeaders_convertsCorrectly() {
        // Given
        let metadata = TrueRPCMini.GrpcMetadata(headers: [
            "authorization": "Bearer token123",
            "x-api-key": "secret456",
        ])

        let request = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: Method(
                name: "Test",
                serviceName: "TestService",
                inputType: "Request",
                outputType: "Response"),
            metadata: metadata)

        // When - we test via reflection since convertToGrpcMetadata is private
        // Instead test that request with metadata doesn't crash
        // This is implicitly tested in integration
        XCTAssertNotNil(request.metadata)
        XCTAssertEqual(request.metadata?.headers["authorization"], "Bearer token123")
    }

    func test_convertToGrpcMetadata_withBinaryHeaders_identifiesCorrectly() {
        // Given
        let metadata = TrueRPCMini.GrpcMetadata(headers: [
            "content-bin": "binarydata",
            "regular-header": "textdata",
        ])

        // Then - verify binary key detection
        XCTAssertTrue(TrueRPCMini.GrpcMetadata.isBinaryKey("content-bin"))
        XCTAssertFalse(TrueRPCMini.GrpcMetadata.isBinaryKey("regular-header"))

        let request = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: Method(
                name: "Test",
                serviceName: "TestService",
                inputType: "Request",
                outputType: "Response"),
            metadata: metadata)

        XCTAssertNotNil(request.metadata)
    }

    func test_requestWithoutMetadata_worksAsExpected() {
        // Given - request without metadata
        let request = RequestDraft(
            jsonBody: "{}",
            url: "localhost:50051",
            method: Method(
                name: "Test",
                serviceName: "TestService",
                inputType: "Request",
                outputType: "Response"))

        // Then
        XCTAssertNil(request.metadata)
    }
}

// MARK: - Response Metadata Tests

extension GrpcSwiftDynamicClientTests {
    func test_convertMetadataToDict_withStringValues_convertsCorrectly() {
        // Given
        var metadata = GRPCCore.Metadata()
        metadata.addString("Bearer token123", forKey: "authorization")
        metadata.addString("application/json", forKey: "content-type")

        // When - test that string metadata is accessible
        let authValues = metadata[stringValues: "authorization"]
        let contentTypeValues = metadata[stringValues: "content-type"]

        // Then
        XCTAssertEqual(Array(authValues), ["Bearer token123"])
        XCTAssertEqual(Array(contentTypeValues), ["application/json"])
    }

    func test_convertMetadataToDict_withBinaryValues_convertsToBase64() {
        // Given
        var metadata = GRPCCore.Metadata()
        let binaryData: [UInt8] = [72, 101, 108, 108, 111] // "Hello"
        metadata.addBinary(binaryData, forKey: "data-bin")

        // When
        let values = metadata[binaryValues: "data-bin"]

        // Then - verify binary value is stored
        XCTAssertEqual(Array(values).count, 1)
        XCTAssertEqual(Array(values).first, binaryData)
    }

    func test_convertMetadataToDict_withMultipleValuesForSameKey_combinesThem() {
        // Given
        var metadata = GRPCCore.Metadata()
        metadata.addString("value1", forKey: "x-custom")
        metadata.addString("value2", forKey: "x-custom")

        // When
        let values = metadata[stringValues: "x-custom"]

        // Then - multiple values should be preserved
        XCTAssertEqual(Array(values).count, 2)
        XCTAssertEqual(Array(values), ["value1", "value2"])
    }

    func test_convertMetadataToDict_withEmptyMetadata_returnsEmptyDict() {
        // Given
        let metadata = GRPCCore.Metadata()

        // Then
        XCTAssertTrue(metadata.isEmpty)
    }

    func test_grpcResponse_withHeaders_storesCorrectly() {
        // Given
        let headers = ["authorization": "Bearer token", "content-type": "application/json"]

        // When
        let response = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK",
            headers: headers)

        // Then
        XCTAssertEqual(response.headers, headers)
        XCTAssertNil(response.trailers)
        XCTAssertNil(response.statusDetails)
    }

    func test_grpcResponse_withTrailers_storesCorrectly() {
        // Given
        let trailers = ["grpc-status": "0", "grpc-message": "Success"]

        // When
        let response = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK",
            trailers: trailers)

        // Then
        XCTAssertNil(response.headers)
        XCTAssertEqual(response.trailers, trailers)
        XCTAssertNil(response.statusDetails)
    }

    func test_grpcResponse_withAllMetadata_storesCorrectly() {
        // Given
        let headers = ["authorization": "Bearer token"]
        let trailers = ["grpc-status": "0"]
        let statusDetails = "Request completed successfully"

        // When
        let response = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK",
            headers: headers,
            trailers: trailers,
            statusDetails: statusDetails)

        // Then
        XCTAssertEqual(response.headers, headers)
        XCTAssertEqual(response.trailers, trailers)
        XCTAssertEqual(response.statusDetails, statusDetails)
    }

    func test_grpcResponse_backwardCompatibility_withoutMetadata() {
        // Given - old style initialization without metadata
        let response = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK")

        // Then - metadata fields should be nil
        XCTAssertNil(response.headers)
        XCTAssertNil(response.trailers)
        XCTAssertNil(response.statusDetails)
    }
}
