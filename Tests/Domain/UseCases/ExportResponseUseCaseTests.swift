import XCTest
@testable import TrueRPCMini

/// Tests for ExportResponseUseCase
/// Validates response export to file functionality
final class ExportResponseUseCaseTests: XCTestCase {
    
    // MARK: - Test: Successful export
    
    func test_execute_whenValidResponse_savesToFile() async throws {
        // Given
        let mockFileManager = MockFileManager()
        let useCase = ExportResponseUseCase(fileManager: mockFileManager)
        
        let response = GrpcResponse(
            jsonBody: """
            {
              "id": 123,
              "name": "Test User"
            }
            """,
            responseTime: 0.5,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        let destinationURL = URL(fileURLWithPath: "/tmp/response.json")
        
        // When
        try await useCase.execute(response: response, destination: destinationURL)
        
        // Then
        XCTAssertTrue(mockFileManager.writeWasCalled)
        XCTAssertEqual(mockFileManager.writtenURL, destinationURL)
        XCTAssertEqual(mockFileManager.writtenData, response.jsonBody.data(using: .utf8))
    }
    
    // MARK: - Test: Export with metadata
    
    func test_execute_whenExportWithMetadata_includesResponseInfo() async throws {
        // Given
        let mockFileManager = MockFileManager()
        let useCase = ExportResponseUseCase(fileManager: mockFileManager)
        
        let response = GrpcResponse(
            jsonBody: "{\"result\": \"success\"}",
            responseTime: 1.234,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        let destinationURL = URL(fileURLWithPath: "/tmp/response_with_meta.json")
        
        // When
        try await useCase.execute(
            response: response,
            destination: destinationURL,
            includeMetadata: true
        )
        
        // Then
        XCTAssertTrue(mockFileManager.writeWasCalled)
        
        // Verify written data contains metadata
        let writtenString = String(data: mockFileManager.writtenData!, encoding: .utf8)!
        XCTAssertTrue(writtenString.contains("responseTime"))
        XCTAssertTrue(writtenString.contains("statusCode"))
        XCTAssertTrue(writtenString.contains("statusMessage"))
    }
    
    // MARK: - Test: File write error
    
    func test_execute_whenFileWriteFails_throwsError() async throws {
        // Given
        let mockFileManager = MockFileManager()
        mockFileManager.shouldFail = true
        let useCase = ExportResponseUseCase(fileManager: mockFileManager)
        
        let response = GrpcResponse(
            jsonBody: "{}",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        let destinationURL = URL(fileURLWithPath: "/tmp/fail.json")
        
        // When/Then
        do {
            try await useCase.execute(response: response, destination: destinationURL)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected error
            XCTAssertTrue(error is ExportError)
        }
    }
    
    // MARK: - Test: Empty response
    
    func test_execute_whenEmptyResponse_savesEmptyObject() async throws {
        // Given
        let mockFileManager = MockFileManager()
        let useCase = ExportResponseUseCase(fileManager: mockFileManager)
        
        let response = GrpcResponse(
            jsonBody: "",
            responseTime: 0.1,
            statusCode: 0,
            statusMessage: "OK"
        )
        
        let destinationURL = URL(fileURLWithPath: "/tmp/empty.json")
        
        // When
        try await useCase.execute(response: response, destination: destinationURL)
        
        // Then
        XCTAssertTrue(mockFileManager.writeWasCalled)
        // Empty string should still be written
        XCTAssertEqual(mockFileManager.writtenData, Data())
    }
    
    // MARK: - Test: Generate default filename
    
    func test_generateFilename_createsTimestampedName() {
        // Given
        let useCase = ExportResponseUseCase(fileManager: MockFileManager())
        
        // When
        let filename = useCase.generateDefaultFilename()
        
        // Then
        XCTAssertTrue(filename.hasPrefix("response_"))
        XCTAssertTrue(filename.hasSuffix(".json"))
    }
}

// MARK: - Mocks

class MockFileManager: FileManagerProtocol {
    var writeWasCalled = false
    var writtenURL: URL?
    var writtenData: Data?
    var shouldFail = false
    
    func write(_ data: Data, to url: URL) throws {
        writeWasCalled = true
        writtenURL = url
        writtenData = data
        
        if shouldFail {
            throw ExportError.fileWriteFailed
        }
    }
}

/// Export-specific errors
enum ExportError: Error {
    case fileWriteFailed
}
