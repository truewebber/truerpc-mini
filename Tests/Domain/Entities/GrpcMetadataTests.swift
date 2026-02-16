import XCTest
@testable import TrueRPCMini

final class GrpcMetadataTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func test_init_createsEmptyMetadata() {
        let metadata = GrpcMetadata()
        
        XCTAssertTrue(metadata.headers.isEmpty)
    }
    
    func test_init_withHeaders_storesHeaders() {
        let headers = ["authorization": "Bearer token", "x-api-key": "secret"]
        
        let metadata = GrpcMetadata(headers: headers)
        
        XCTAssertEqual(metadata.headers, headers)
    }
    
    // MARK: - Binary Metadata Tests
    
    func test_isBinaryKey_returnsTrueForBinSuffix() {
        XCTAssertTrue(GrpcMetadata.isBinaryKey("content-bin"))
        XCTAssertTrue(GrpcMetadata.isBinaryKey("data-bin"))
        XCTAssertTrue(GrpcMetadata.isBinaryKey("x-custom-bin"))
    }
    
    func test_isBinaryKey_returnsFalseForNonBinSuffix() {
        XCTAssertFalse(GrpcMetadata.isBinaryKey("authorization"))
        XCTAssertFalse(GrpcMetadata.isBinaryKey("content-type"))
        XCTAssertFalse(GrpcMetadata.isBinaryKey("x-custom"))
        XCTAssertFalse(GrpcMetadata.isBinaryKey("bin"))
        XCTAssertFalse(GrpcMetadata.isBinaryKey("something-binary"))
    }
    
    // MARK: - Equatable Tests
    
    func test_equatable_equalWhenHeadersMatch() {
        let metadata1 = GrpcMetadata(headers: ["key": "value"])
        let metadata2 = GrpcMetadata(headers: ["key": "value"])
        
        XCTAssertEqual(metadata1, metadata2)
    }
    
    func test_equatable_notEqualWhenHeadersDiffer() {
        let metadata1 = GrpcMetadata(headers: ["key": "value1"])
        let metadata2 = GrpcMetadata(headers: ["key": "value2"])
        
        XCTAssertNotEqual(metadata1, metadata2)
    }
    
    func test_equatable_emptyMetadataEqual() {
        let metadata1 = GrpcMetadata()
        let metadata2 = GrpcMetadata()
        
        XCTAssertEqual(metadata1, metadata2)
    }
    
    // MARK: - JSON Conversion Tests
    
    func test_fromJSON_parsesValidJSON() throws {
        let json = """
        {
            "authorization": "Bearer token",
            "x-api-key": "secret"
        }
        """
        
        let metadata = try GrpcMetadata.from(json: json)
        
        XCTAssertEqual(metadata.headers["authorization"], "Bearer token")
        XCTAssertEqual(metadata.headers["x-api-key"], "secret")
    }
    
    func test_fromJSON_parsesEmptyJSON() throws {
        let json = "{}"
        
        let metadata = try GrpcMetadata.from(json: json)
        
        XCTAssertTrue(metadata.headers.isEmpty)
    }
    
    func test_fromJSON_throwsOnInvalidJSON() {
        let json = "{ invalid }"
        
        XCTAssertThrowsError(try GrpcMetadata.from(json: json))
    }
    
    func test_fromJSON_throwsOnNonObjectJSON() {
        let json = "[\"array\"]"
        
        XCTAssertThrowsError(try GrpcMetadata.from(json: json))
    }
    
    func test_toJSON_convertsToJSONString() throws {
        let metadata = GrpcMetadata(headers: [
            "authorization": "Bearer token",
            "x-api-key": "secret"
        ])
        
        let json = try metadata.toJSON()
        let parsed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: String]
        
        XCTAssertEqual(parsed?["authorization"], "Bearer token")
        XCTAssertEqual(parsed?["x-api-key"], "secret")
    }
    
    func test_toJSON_emptyMetadataReturnsEmptyObject() throws {
        let metadata = GrpcMetadata()
        
        let json = try metadata.toJSON()
        
        XCTAssertEqual(json, "{}")
    }
}
