import XCTest
@testable import TrueRPCMini

final class UserDefaultsImportPathsRepositoryTests: XCTestCase {
    
    var sut: UserDefaultsImportPathsRepository!
    var userDefaults: UserDefaults!
    
    override func setUp() {
        super.setUp()
        // Use a separate suite name for testing to avoid conflicts
        userDefaults = UserDefaults(suiteName: "test.import.paths")!
        userDefaults.removePersistentDomain(forName: "test.import.paths")
        sut = UserDefaultsImportPathsRepository(userDefaults: userDefaults)
    }
    
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "test.import.paths")
        sut = nil
        userDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func test_getImportPaths_whenNoPreviousData_returnsEmptyArray() {
        // When
        let paths = sut.getImportPaths()
        
        // Then
        XCTAssertTrue(paths.isEmpty)
    }
    
    // MARK: - Save and Retrieve Tests
    
    func test_saveImportPaths_storesPathsInUserDefaults() {
        // Given
        let testPaths = ["/Users/test/protos", "/opt/protos"]
        
        // When
        sut.saveImportPaths(testPaths)
        
        // Then
        let retrieved = sut.getImportPaths()
        XCTAssertEqual(retrieved, testPaths)
    }
    
    func test_saveImportPaths_withEmptyArray_clearsExistingPaths() {
        // Given
        sut.saveImportPaths(["/Users/test/protos"])
        
        // When
        sut.saveImportPaths([])
        
        // Then
        let retrieved = sut.getImportPaths()
        XCTAssertTrue(retrieved.isEmpty)
    }
    
    func test_saveImportPaths_overwritesPreviousData() {
        // Given
        let initialPaths = ["/path/one", "/path/two"]
        let newPaths = ["/path/three"]
        sut.saveImportPaths(initialPaths)
        
        // When
        sut.saveImportPaths(newPaths)
        
        // Then
        let retrieved = sut.getImportPaths()
        XCTAssertEqual(retrieved, newPaths)
        XCTAssertNotEqual(retrieved, initialPaths)
    }
    
    // MARK: - Persistence Tests
    
    func test_importPaths_persistAcrossInstances() {
        // Given
        let testPaths = ["/Users/test/protos", "/opt/protos"]
        sut.saveImportPaths(testPaths)
        
        // When - Create new instance with same UserDefaults
        let newRepository = UserDefaultsImportPathsRepository(userDefaults: userDefaults)
        let retrieved = newRepository.getImportPaths()
        
        // Then
        XCTAssertEqual(retrieved, testPaths)
    }
    
    // MARK: - Edge Cases
    
    func test_saveImportPaths_withSpecialCharacters_preservesCorrectly() {
        // Given
        let testPaths = [
            "/path/with spaces/protos",
            "/path/with-dashes/protos",
            "/path/with_underscores/protos"
        ]
        
        // When
        sut.saveImportPaths(testPaths)
        
        // Then
        let retrieved = sut.getImportPaths()
        XCTAssertEqual(retrieved, testPaths)
    }
    
    func test_saveImportPaths_withDuplicates_preservesDuplicates() {
        // Given
        let testPaths = ["/path/one", "/path/one", "/path/two"]
        
        // When
        sut.saveImportPaths(testPaths)
        
        // Then
        let retrieved = sut.getImportPaths()
        XCTAssertEqual(retrieved, testPaths)
        XCTAssertEqual(retrieved.count, 3)
    }
}
