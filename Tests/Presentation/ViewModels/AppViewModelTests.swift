import XCTest
@testable import TrueRPCMini

/// Tests for AppViewModel - main app coordinator
@MainActor
final class AppViewModelTests: XCTestCase {
    
    fileprivate var sut: AppViewModel!
    fileprivate var createTabUseCase: CreateEditorTabUseCase!
    fileprivate var generateMockDataUseCase: GenerateMockDataUseCase!
    fileprivate var executeRequestUseCase: MockExecuteRequestUseCase!
    fileprivate var exportResponseUseCase: ExportResponseUseCase!
    
    override func setUp() {
        super.setUp()
        
        // Use real use cases (they're simple and have no dependencies)
        createTabUseCase = CreateEditorTabUseCase()
        generateMockDataUseCase = GenerateMockDataUseCase(
            mockDataGenerator: MockDataGenerator()
        )
        exportResponseUseCase = ExportResponseUseCase(
            fileManager: AppMockFileManager()
        )
        
        // Only mock the execute use case (requires network)
        executeRequestUseCase = MockExecuteRequestUseCase()
        
        sut = AppViewModel(
            createEditorTabUseCase: createTabUseCase,
            generateMockDataUseCase: generateMockDataUseCase,
            executeRequestUseCase: executeRequestUseCase,
            exportResponseUseCase: exportResponseUseCase
        )
    }
    
    override func tearDown() {
        sut = nil
        createTabUseCase = nil
        generateMockDataUseCase = nil
        executeRequestUseCase = nil
        exportResponseUseCase = nil
        super.tearDown()
    }
    
    // MARK: - Initial State
    
    func test_init_selectedTabIsNil() {
        // Then
        XCTAssertNil(sut.selectedEditorTab)
    }
    
    // MARK: - Open Method
    
    func test_openMethod_createsAndSetsEditorTabViewModel() {
        // Given
        let method = TrueRPCMini.Method(
            name: "GetUser",
            serviceName: "UserService",
            inputType: ".test.GetUserRequest",
            outputType: ".test.User"
        )
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "test.proto",
            path: URL(fileURLWithPath: "/test/test.proto"),
            services: [service]
        )
        
        // When
        sut.openMethod(method: method, service: service, protoFile: protoFile)
        
        // Then
        XCTAssertNotNil(sut.selectedEditorTab)
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.methodName, "GetUser")
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.serviceName, "UserService")
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.protoFile.name, "test.proto")
    }
    
    func test_openMethod_createsViewModelWithCorrectMethod() {
        // Given
        let method = TrueRPCMini.Method(
            name: "CreateUser",
            serviceName: "UserService",
            inputType: ".test.CreateUserRequest",
            outputType: ".test.User"
        )
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/protos/users.proto"),
            services: [service]
        )
        
        // When
        sut.openMethod(method: method, service: service, protoFile: protoFile)
        
        // Then
        XCTAssertNotNil(sut.selectedEditorTab)
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.method.name, "CreateUser")
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.method.inputType, ".test.CreateUserRequest")
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.method.outputType, ".test.User")
    }
    
    func test_openMethod_viewModelCanUpdateState() {
        // Given
        let method = TrueRPCMini.Method(
            name: "DeleteUser",
            serviceName: "UserService",
            inputType: ".test.DeleteUserRequest",
            outputType: ".test.Empty"
        )
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/protos/users.proto"),
            services: [service]
        )
        
        // When
        sut.openMethod(method: method, service: service, protoFile: protoFile)
        
        // Then - Verify ViewModel is functional
        let tabVM = sut.selectedEditorTab!
        
        tabVM.updateJson(#"{"id": 123}"#)
        XCTAssertEqual(tabVM.requestJson, #"{"id": 123}"#)
        
        tabVM.updateUrl("localhost:9090")
        XCTAssertEqual(tabVM.url, "localhost:9090")
    }
    
    func test_openMethod_multipleCalls_replacesSelectedTab() {
        // Given
        let method1 = TrueRPCMini.Method(
            name: "Method1",
            serviceName: "Service1",
            inputType: ".test.Request1",
            outputType: ".test.Response1"
        )
        let service1 = Service(name: "Service1", methods: [method1])
        let protoFile1 = ProtoFile(
            name: "test1.proto",
            path: URL(fileURLWithPath: "/test/test1.proto"),
            services: [service1]
        )
        
        let method2 = TrueRPCMini.Method(
            name: "Method2",
            serviceName: "Service2",
            inputType: ".test.Request2",
            outputType: ".test.Response2"
        )
        let service2 = Service(name: "Service2", methods: [method2])
        let protoFile2 = ProtoFile(
            name: "test2.proto",
            path: URL(fileURLWithPath: "/test/test2.proto"),
            services: [service2]
        )
        
        // When
        sut.openMethod(method: method1, service: service1, protoFile: protoFile1)
        let firstTabId = sut.selectedEditorTab?.editorTab.id
        
        sut.openMethod(method: method2, service: service2, protoFile: protoFile2)
        let secondTabId = sut.selectedEditorTab?.editorTab.id
        
        // Then
        XCTAssertNotEqual(firstTabId, secondTabId)
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.methodName, "Method2")
        XCTAssertEqual(sut.selectedEditorTab?.editorTab.serviceName, "Service2")
    }
}

// MARK: - Mock Execute Request Use Case

fileprivate class MockExecuteRequestUseCase: ExecuteUnaryRequestUseCaseProtocol {
    func execute(request: RequestDraft, method: TrueRPCMini.Method) async throws -> GrpcResponse {
        return GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK"
        )
    }
}

// MARK: - Mock File Manager

fileprivate class AppMockFileManager: FileManagerProtocol {
    func write(_ data: Data, to url: URL) throws {
        // No-op for testing
    }
}
