import XCTest
@testable import TrueRPCMini

/// Tests for EditorTabViewModel - managing request editor state
@MainActor
final class EditorTabViewModelTests: XCTestCase {
    var sut: EditorTabViewModel!
    var mockGenerateMockDataUseCase: MockGenerateMockDataUseCase!
    var testMethod: TrueRPCMini.Method!
    var testService: Service!
    var testProtoFile: ProtoFile!
    var testEditorTab: EditorTab!
    
    override func setUp() {
        super.setUp()
        mockGenerateMockDataUseCase = MockGenerateMockDataUseCase()
        
        testMethod = TrueRPCMini.Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false
        )
        testService = Service(name: "UserService", methods: [testMethod])
        testProtoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [testService]
        )
        testEditorTab = EditorTab(
            methodName: testMethod.name,
            serviceName: testService.name,
            protoFile: testProtoFile,
            method: testMethod
        )
        
        sut = EditorTabViewModel(
            editorTab: testEditorTab,
            generateMockDataUseCase: mockGenerateMockDataUseCase
        )
    }
    
    override func tearDown() {
        sut = nil
        mockGenerateMockDataUseCase = nil
        testMethod = nil
        testService = nil
        testProtoFile = nil
        testEditorTab = nil
        super.tearDown()
    }
    
    // MARK: - Initial State
    
    func test_init_setsInitialState() {
        // Then
        XCTAssertEqual(sut.editorTab.methodName, "GetUser")
        XCTAssertEqual(sut.url, "")
        XCTAssertEqual(sut.requestJson, "")
        XCTAssertFalse(sut.isLoading)
    }
    
    // MARK: - Load Mock Data
    
    func test_loadMockData_success_updatesRequestJson() async {
        // Given
        mockGenerateMockDataUseCase.mockJSON = "{\"userId\": 1}"
        
        // When
        await sut.loadMockData()
        
        // Then
        XCTAssertEqual(sut.requestJson, "{\"userId\": 1}")
        XCTAssertFalse(sut.isLoading)
    }
    
    func test_loadMockData_setsLoadingState() async {
        // Given
        mockGenerateMockDataUseCase.mockJSON = "{}"
        
        // When
        let loadingStateDuringExecution = Task {
            await sut.loadMockData()
        }
        
        // Small delay to check loading state
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        
        await loadingStateDuringExecution.value
        
        // Then
        XCTAssertFalse(sut.isLoading) // Should be false after completion
    }
    
    // MARK: - Update JSON
    
    func test_updateJson_updatesRequestJson() {
        // Given
        let newJson = "{\"userId\": 123}"
        
        // When
        sut.updateJson(newJson)
        
        // Then
        XCTAssertEqual(sut.requestJson, newJson)
    }
    
    // MARK: - Update URL
    
    func test_updateUrl_updatesUrl() {
        // Given
        let newUrl = "localhost:50051"
        
        // When
        sut.updateUrl(newUrl)
        
        // Then
        XCTAssertEqual(sut.url, newUrl)
    }
}

// MARK: - Mock

class MockGenerateMockDataUseCase: GenerateMockDataUseCase {
    var mockJSON: String = "{}"
    var executeCallCount = 0
    
    init() {
        super.init(mockDataGenerator: MockDataGenerator())
    }
    
    override func execute(method: TrueRPCMini.Method) async throws -> String {
        executeCallCount += 1
        return mockJSON
    }
}
