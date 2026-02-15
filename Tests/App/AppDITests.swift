import XCTest
@testable import TrueRPCMini

final class AppDITests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func test_init_createsContainer() {
        // Given & When
        let sut = AppDI()
        
        // Then
        XCTAssertNotNil(sut, "AppDI container should be initialized")
    }
    
    func test_init_registersSingletonInstance() {
        // Given
        let sut = AppDI()
        
        // When
        let instance1 = sut.resolve()
        let instance2 = sut.resolve()
        
        // Then
        XCTAssertTrue(instance1 === instance2, "AppDI should return the same singleton instance")
    }
    
    // MARK: - Registration Tests
    
    func test_register_storesFactory() {
        // Given
        let sut = AppDI()
        protocol TestService {}
        class TestServiceImpl: TestService {}
        
        // When
        sut.register(TestService.self) { TestServiceImpl() }
        let resolved = sut.resolve(TestService.self)
        
        // Then
        XCTAssertNotNil(resolved, "Registered service should be resolvable")
        XCTAssertTrue(resolved is TestServiceImpl, "Resolved service should be of registered type")
    }
    
    func test_register_withSingleton_returnsSameInstance() {
        // Given
        let sut = AppDI()
        protocol TestService {}
        class TestServiceImpl: TestService {}
        
        // When
        sut.register(TestService.self, lifecycle: .singleton) { TestServiceImpl() }
        let instance1 = sut.resolve(TestService.self)
        let instance2 = sut.resolve(TestService.self)
        
        // Then
        XCTAssertTrue(instance1 as AnyObject === instance2 as AnyObject, 
                     "Singleton lifecycle should return same instance")
    }
    
    func test_register_withTransient_returnsDifferentInstances() {
        // Given
        let sut = AppDI()
        protocol TestService {}
        class TestServiceImpl: TestService {}
        
        // When
        sut.register(TestService.self, lifecycle: .transient) { TestServiceImpl() }
        let instance1 = sut.resolve(TestService.self)
        let instance2 = sut.resolve(TestService.self)
        
        // Then
        XCTAssertFalse(instance1 as AnyObject === instance2 as AnyObject,
                      "Transient lifecycle should return different instances")
    }
    
    // MARK: - Resolution Tests
    
    func test_resolve_whenNotRegistered_returnsNil() {
        // Given
        let sut = AppDI()
        protocol UnregisteredService {}
        
        // When
        let resolved = sut.resolve(UnregisteredService.self)
        
        // Then
        XCTAssertNil(resolved, "Unregistered service should return nil")
    }
    
    func test_resolve_withDependencies_injectsCorrectly() {
        // Given
        let sut = AppDI()
        protocol Repository {}
        class RepositoryImpl: Repository {}
        
        protocol UseCase {
            var repository: Repository { get }
        }
        class UseCaseImpl: UseCase {
            let repository: Repository
            init(repository: Repository) {
                self.repository = repository
            }
        }
        
        // When
        sut.register(Repository.self) { RepositoryImpl() }
        sut.register(UseCase.self) { 
            UseCaseImpl(repository: sut.resolve(Repository.self)!)
        }
        let resolved = sut.resolve(UseCase.self)
        
        // Then
        XCTAssertNotNil(resolved, "UseCase should be resolved")
        XCTAssertNotNil(resolved?.repository, "UseCase should have injected repository")
    }
    
    // MARK: - Reset Tests
    
    func test_reset_clearsAllRegistrations() {
        // Given
        let sut = AppDI()
        protocol TestService {}
        class TestServiceImpl: TestService {}
        sut.register(TestService.self) { TestServiceImpl() }
        
        // When
        sut.reset()
        let resolved = sut.resolve(TestService.self)
        
        // Then
        XCTAssertNil(resolved, "After reset, services should not be resolvable")
    }
}
