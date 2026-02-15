import XCTest
@testable import TrueRPCMini

/// Tests for CreateEditorTabUseCase - creating editor tabs for methods
final class CreateEditorTabUseCaseTests: XCTestCase {
    var sut: CreateEditorTabUseCase!
    
    override func setUp() {
        super.setUp()
        sut = CreateEditorTabUseCase()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Happy Path
    
    func test_execute_createsEditorTab() {
        // Given
        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false
        )
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [service]
        )
        
        // When
        let tab = sut.execute(method: method, service: service, protoFile: protoFile)
        
        // Then
        XCTAssertEqual(tab.methodName, "GetUser")
        XCTAssertEqual(tab.serviceName, "UserService")
        XCTAssertEqual(tab.protoFile.name, "users.proto")
        XCTAssertEqual(tab.method.name, "GetUser")
        XCTAssertNotNil(tab.id)
    }
    
    func test_execute_createsUniqueIds() {
        // Given
        let method = Method(
            name: "GetUser",
            inputType: "GetUserRequest",
            outputType: "GetUserResponse",
            isStreaming: false
        )
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [service]
        )
        
        // When
        let tab1 = sut.execute(method: method, service: service, protoFile: protoFile)
        let tab2 = sut.execute(method: method, service: service, protoFile: protoFile)
        
        // Then
        XCTAssertNotEqual(tab1.id, tab2.id)
    }
    
    func test_execute_withStreamingMethod_createsTab() {
        // Given
        let method = Method(
            name: "StreamUsers",
            inputType: "StreamUsersRequest",
            outputType: "User",
            isStreaming: true
        )
        let service = Service(name: "UserService", methods: [method])
        let protoFile = ProtoFile(
            name: "users.proto",
            path: URL(fileURLWithPath: "/test/users.proto"),
            services: [service]
        )
        
        // When
        let tab = sut.execute(method: method, service: service, protoFile: protoFile)
        
        // Then
        XCTAssertEqual(tab.methodName, "StreamUsers")
        XCTAssertTrue(tab.method.isStreaming)
    }
}
