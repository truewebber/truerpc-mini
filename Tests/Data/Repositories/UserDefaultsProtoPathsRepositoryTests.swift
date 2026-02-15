import XCTest
@testable import TrueRPCMini

/// Tests for UserDefaultsProtoPathsRepository - persisting proto file paths
final class UserDefaultsProtoPathsRepositoryTests: XCTestCase {
    var sut: UserDefaultsProtoPathsRepository!
    var userDefaults: UserDefaults!
    let testKey = "com.truewebber.TrueRPCMini.test.protoPaths"
    
    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: "test-proto-paths")!
        userDefaults.removePersistentDomain(forName: "test-proto-paths")
        sut = UserDefaultsProtoPathsRepository(userDefaults: userDefaults, key: testKey)
    }
    
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: "test-proto-paths")
        sut = nil
        userDefaults = nil
        super.tearDown()
    }
    
    // MARK: - Save & Load Tests
    
    func test_saveAndGet_storesPaths() {
        // Given
        let url1 = URL(fileURLWithPath: "/path/to/proto1.proto")
        let url2 = URL(fileURLWithPath: "/path/to/proto2.proto")
        let urls = [url1, url2]
        
        // When
        sut.saveProtoPaths(urls)
        let retrieved = sut.getProtoPaths()
        
        // Then
        XCTAssertEqual(retrieved.count, 2)
        XCTAssertEqual(retrieved[0], url1)
        XCTAssertEqual(retrieved[1], url2)
    }
    
    func test_saveEmptyArray_storesEmptyArray() {
        // Given
        sut.saveProtoPaths([URL(fileURLWithPath: "/test.proto")])
        
        // When
        sut.saveProtoPaths([])
        let retrieved = sut.getProtoPaths()
        
        // Then
        XCTAssertTrue(retrieved.isEmpty)
    }
    
    func test_getProtoPaths_whenNothingSaved_returnsEmptyArray() {
        // When
        let retrieved = sut.getProtoPaths()
        
        // Then
        XCTAssertTrue(retrieved.isEmpty)
    }
    
    func test_save_overwritesPreviousPaths() {
        // Given
        let url1 = URL(fileURLWithPath: "/path/to/proto1.proto")
        let url2 = URL(fileURLWithPath: "/path/to/proto2.proto")
        
        sut.saveProtoPaths([url1])
        
        // When
        sut.saveProtoPaths([url2])
        let retrieved = sut.getProtoPaths()
        
        // Then
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved[0], url2)
    }
    
    // MARK: - Persistence Tests
    
    func test_persistsAcrossInstances() {
        // Given
        let url = URL(fileURLWithPath: "/path/to/test.proto")
        sut.saveProtoPaths([url])
        
        // When
        let newRepository = UserDefaultsProtoPathsRepository(userDefaults: userDefaults, key: testKey)
        let retrieved = newRepository.getProtoPaths()
        
        // Then
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved[0], url)
    }
    
    // MARK: - Edge Cases
    
    func test_savePathsWithSpecialCharacters() {
        // Given
        let url = URL(fileURLWithPath: "/path/with spaces/файл.proto")
        
        // When
        sut.saveProtoPaths([url])
        let retrieved = sut.getProtoPaths()
        
        // Then
        XCTAssertEqual(retrieved.count, 1)
        XCTAssertEqual(retrieved[0], url)
    }
    
    func test_saveLargeNumberOfPaths() {
        // Given
        let urls = (0..<100).map { URL(fileURLWithPath: "/path/to/proto\($0).proto") }
        
        // When
        sut.saveProtoPaths(urls)
        let retrieved = sut.getProtoPaths()
        
        // Then
        XCTAssertEqual(retrieved.count, 100)
        XCTAssertEqual(retrieved, urls)
    }
}
