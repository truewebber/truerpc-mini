import XCTest
@testable import TrueRPCMini

/// Tests for SystemFileManager
/// Validates file writing operations
final class SystemFileManagerTests: XCTestCase {
    
    var tempDirectory: URL!
    var fileManager: SystemFileManager!
    
    override func setUp() {
        super.setUp()
        // Create temp directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrueRPCMiniTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        fileManager = SystemFileManager()
    }
    
    override func tearDown() {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    // MARK: - Test: Write data to file
    
    func test_write_createsFileWithContent() throws {
        // Given
        let testURL = tempDirectory.appendingPathComponent("test.json")
        let testData = "{\"test\": \"data\"}".data(using: .utf8)!
        
        // When
        try fileManager.write(testData, to: testURL)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: testURL.path))
        
        let readData = try Data(contentsOf: testURL)
        XCTAssertEqual(readData, testData)
    }
    
    // MARK: - Test: Overwrite existing file
    
    func test_write_overwritesExistingFile() throws {
        // Given
        let testURL = tempDirectory.appendingPathComponent("overwrite.json")
        let initialData = "initial".data(using: .utf8)!
        let newData = "updated".data(using: .utf8)!
        
        try fileManager.write(initialData, to: testURL)
        
        // When
        try fileManager.write(newData, to: testURL)
        
        // Then
        let readData = try Data(contentsOf: testURL)
        XCTAssertEqual(readData, newData)
    }
    
    // MARK: - Test: Create intermediate directories
    
    func test_write_createsIntermediateDirectories() throws {
        // Given
        let nestedURL = tempDirectory
            .appendingPathComponent("nested")
            .appendingPathComponent("deep")
            .appendingPathComponent("file.json")
        let testData = "test".data(using: .utf8)!
        
        // When
        try fileManager.write(testData, to: nestedURL)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedURL.path))
        let readData = try Data(contentsOf: nestedURL)
        XCTAssertEqual(readData, testData)
    }
    
    // MARK: - Test: Write empty data
    
    func test_write_handlesEmptyData() throws {
        // Given
        let testURL = tempDirectory.appendingPathComponent("empty.json")
        let emptyData = Data()
        
        // When
        try fileManager.write(emptyData, to: testURL)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: testURL.path))
        let readData = try Data(contentsOf: testURL)
        XCTAssertEqual(readData.count, 0)
    }
    
    // MARK: - Test: Write large data
    
    func test_write_handlesLargeData() throws {
        // Given
        let testURL = tempDirectory.appendingPathComponent("large.json")
        // Create 1MB of data
        let largeData = Data(repeating: 0xFF, count: 1024 * 1024)
        
        // When
        try fileManager.write(largeData, to: testURL)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: testURL.path))
        let readData = try Data(contentsOf: testURL)
        XCTAssertEqual(readData.count, largeData.count)
    }
    
    // MARK: - Test: Write with special characters in filename
    
    func test_write_handlesSpecialCharactersInFilename() throws {
        // Given
        let testURL = tempDirectory.appendingPathComponent("файл тест.json")
        let testData = "special".data(using: .utf8)!
        
        // When
        try fileManager.write(testData, to: testURL)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: testURL.path))
        let readData = try Data(contentsOf: testURL)
        XCTAssertEqual(readData, testData)
    }
}
