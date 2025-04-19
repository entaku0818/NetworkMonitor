import XCTest
@testable import NetworkMonitor

final class HTTPResponseTests: XCTestCase {
    
    func testHTTPResponseInitialization() {
        // Arrange
        let statusCode = 200
        let headers = ["Content-Type": "application/json", "Server": "nginx"]
        let bodyString = "{\"success\":true,\"message\":\"OK\"}"
        let body = bodyString.data(using: .utf8)
        let timestamp = Date()
        let duration = 0.35
        let mimeType = "application/json"
        let encoding = "utf-8"
        
        // Act
        let response = HTTPResponse(
            statusCode: statusCode,
            headers: headers,
            body: body,
            timestamp: timestamp,
            duration: duration,
            mimeType: mimeType,
            encoding: encoding
        )
        
        // Assert
        XCTAssertEqual(response.statusCode, statusCode)
        XCTAssertEqual(response.statusCategory, .success)
        XCTAssertEqual(response.headers, headers)
        XCTAssertEqual(response.body, body)
        XCTAssertEqual(response.timestamp, timestamp)
        XCTAssertEqual(response.duration, duration)
        XCTAssertEqual(response.mimeType, mimeType)
        XCTAssertEqual(response.encoding, encoding)
        XCTAssertEqual(response.contentLength, Int64(body?.count ?? 0))
        XCTAssertFalse(response.fromCache)
        XCTAssertNil(response.error)
    }
    
    func testStatusCodeCategory() {
        // Test informational (100-199)
        let info = HTTPResponse(statusCode: 101)
        XCTAssertEqual(info.statusCategory, .informational)
        
        // Test success (200-299)
        let success = HTTPResponse(statusCode: 200)
        XCTAssertEqual(success.statusCategory, .success)
        
        // Test redirection (300-399)
        let redirect = HTTPResponse(statusCode: 301)
        XCTAssertEqual(redirect.statusCategory, .redirection)
        
        // Test client error (400-499)
        let clientError = HTTPResponse(statusCode: 404)
        XCTAssertEqual(clientError.statusCategory, .clientError)
        
        // Test server error (500-599)
        let serverError = HTTPResponse(statusCode: 500)
        XCTAssertEqual(serverError.statusCategory, .serverError)
        
        // Test unknown
        let unknown = HTTPResponse(statusCode: 600)
        XCTAssertEqual(unknown.statusCategory, .unknown)
    }
    
    func testFromURLResponse() {
        // Arrange
        let url = URL(string: "https://api.example.com/data")!
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json", "Server": "nginx"]
        )!
        let bodyString = "{\"result\":\"success\"}"
        let data = bodyString.data(using: .utf8)
        let duration = 0.5
        
        // Act
        let response = HTTPResponse.from(
            urlResponse: httpResponse,
            data: data,
            duration: duration
        )
        
        // Assert
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.statusCategory, .success)
        XCTAssertEqual(response.headers["Content-Type"], "application/json")
        XCTAssertEqual(response.headers["Server"], "nginx")
        XCTAssertEqual(response.body, data)
        XCTAssertEqual(response.duration, duration)
    }
    
    func testBodyAsString() {
        // Arrange - UTF8
        let utf8Body = "{\"message\":\"こんにちは\"}"
        let utf8Data = utf8Body.data(using: .utf8)
        let utf8Response = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: utf8Data
        )
        
        // Act & Assert - UTF8
        XCTAssertEqual(utf8Response.bodyAsString(), utf8Body)
        
        // Arrange - ASCII
        let asciiBody = "Hello World"
        let asciiData = asciiBody.data(using: .ascii)
        let asciiResponse = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/plain; charset=ascii"],
            body: asciiData
        )
        
        // Act & Assert - ASCII
        XCTAssertEqual(asciiResponse.bodyAsString(), asciiBody)
        
        // Test with explicit encoding
        XCTAssertEqual(utf8Response.bodyAsString(using: .utf8), utf8Body)
    }
    
    func testDecodeBody() {
        // Arrange
        struct TestModel: Codable, Equatable {
            let status: String
            let code: Int
        }
        
        let testModel = TestModel(status: "success", code: 200)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(testModel)
        let response = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: data
        )
        
        // Act
        let decodedModel = response.decodeBody(as: TestModel.self)
        
        // Assert
        XCTAssertNotNil(decodedModel)
        XCTAssertEqual(decodedModel, testModel)
    }
    
    func testStatusHelpers() {
        // Success
        let success = HTTPResponse(statusCode: 200)
        XCTAssertTrue(success.isSuccess)
        XCTAssertFalse(success.isClientError)
        XCTAssertFalse(success.isServerError)
        XCTAssertFalse(success.isError)
        
        // Client Error
        let clientError = HTTPResponse(statusCode: 404)
        XCTAssertFalse(clientError.isSuccess)
        XCTAssertTrue(clientError.isClientError)
        XCTAssertFalse(clientError.isServerError)
        XCTAssertTrue(clientError.isError)
        
        // Server Error
        let serverError = HTTPResponse(statusCode: 500)
        XCTAssertFalse(serverError.isSuccess)
        XCTAssertFalse(serverError.isClientError)
        XCTAssertTrue(serverError.isServerError)
        XCTAssertTrue(serverError.isError)
        
        // With Error
        let error = NSError(domain: "test", code: 0, userInfo: nil)
        let withError = HTTPResponse(statusCode: 200, error: error)
        XCTAssertTrue(withError.isSuccess) // Status is still 200
        XCTAssertTrue(withError.isError)   // But has error
    }
    
    func testContentLength() {
        // From Header
        let withHeader = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Length": "1024"],
            body: Data(repeating: 0, count: 100) // Actual body is smaller
        )
        XCTAssertEqual(withHeader.contentLength, 1024)
        
        // From Body
        let fromBody = HTTPResponse(
            statusCode: 200,
            headers: [:], // No Content-Length header
            body: Data(repeating: 0, count: 512)
        )
        XCTAssertEqual(fromBody.contentLength, 512)
    }
    
    func testEquatable() {
        // Arrange
        let response1 = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: "{\"test\":true}".data(using: .utf8)
        )
        
        let response2 = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: "{\"test\":true}".data(using: .utf8)
        )
        
        let response3 = HTTPResponse(
            statusCode: 404,
            headers: ["Content-Type": "application/json"],
            body: "{\"error\":\"Not Found\"}".data(using: .utf8)
        )
        
        // Assert
        XCTAssertEqual(response1, response2)
        XCTAssertNotEqual(response1, response3)
    }
    
    func testDescription() {
        // Arrange
        let statusCode = 200
        let headers = ["Content-Type": "application/json"]
        let bodyString = "{\"status\":\"OK\"}"
        let body = bodyString.data(using: .utf8)
        let duration = 0.123
        
        let response = HTTPResponse(
            statusCode: statusCode,
            headers: headers,
            body: body,
            duration: duration
        )
        
        // Act
        let description = response.description
        
        // Assert
        XCTAssertTrue(description.contains("Status: 200"))
        XCTAssertTrue(description.contains("Content-Type"))
        XCTAssertTrue(description.contains("application/json"))
        XCTAssertTrue(description.contains(bodyString))
        XCTAssertTrue(description.contains("Duration: 0.123s"))
    }
    
    func testCodable() {
        // Arrange
        let original = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: "{\"test\":true}".data(using: .utf8),
            duration: 0.5,
            mimeType: "application/json",
            encoding: "utf-8"
        )
        
        // Act - Encode and decode
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(HTTPResponse.self, from: data)
            
            // Assert
            XCTAssertEqual(decoded.statusCode, original.statusCode)
            XCTAssertEqual(decoded.statusCategory, original.statusCategory)
            XCTAssertEqual(decoded.headers, original.headers)
            XCTAssertEqual(decoded.body, original.body)
            XCTAssertEqual(decoded.duration, original.duration)
            XCTAssertEqual(decoded.mimeType, original.mimeType)
            XCTAssertEqual(decoded.encoding, original.encoding)
        } catch {
            XCTFail("Failed to encode/decode HTTPResponse: \(error)")
        }
    }
    
    func testErrorEncoding() {
        // Arrange
        let error = NSError(domain: "TestDomain", code: 123, userInfo: [
            NSLocalizedDescriptionKey: "Test error message"
        ])
        let original = HTTPResponse(
            statusCode: 500,
            error: error
        )
        
        // Act - Encode and decode
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(HTTPResponse.self, from: data)
            
            // Assert
            XCTAssertEqual(decoded.statusCode, original.statusCode)
            XCTAssertNotNil(decoded.error)
            XCTAssertEqual(decoded.error?.localizedDescription, "Test error message")
        } catch {
            XCTFail("Failed to encode/decode HTTPResponse with error: \(error)")
        }
    }
} 