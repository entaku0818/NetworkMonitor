import XCTest
@testable import NetworkMonitor

final class HTTPRequestTests: XCTestCase {
    
    func testHTTPRequestInitialization() {
        // Arrange
        let url = "https://api.example.com/data"
        let method = HTTPRequest.Method.get
        let headers = ["Content-Type": "application/json", "Authorization": "Bearer token123"]
        let bodyString = "{\"name\":\"Test\",\"value\":123}"
        let body = bodyString.data(using: .utf8)
        
        // Act
        let request = HTTPRequest(url: url, method: method, headers: headers, body: body)
        
        // Assert
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.method, method)
        XCTAssertEqual(request.headers, headers)
        XCTAssertEqual(request.body, body)
        XCTAssertNotNil(request.timestamp)
        XCTAssertNotNil(request.hash)
        XCTAssertNotNil(request.urlComponents)
        XCTAssertEqual(request.urlComponents?.host, "api.example.com")
        XCTAssertEqual(request.urlComponents?.path, "/data")
    }
    
    func testConversionFromURLRequest() {
        // Arrange
        let url = URL(string: "https://api.example.com/data?param=value")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = ["Content-Type": "application/json"]
        let bodyString = "{\"key\":\"value\"}"
        urlRequest.httpBody = bodyString.data(using: .utf8)
        
        // Act
        let httpRequest = HTTPRequest.from(urlRequest: urlRequest)
        
        // Assert
        XCTAssertNotNil(httpRequest)
        XCTAssertEqual(httpRequest?.url, url.absoluteString)
        XCTAssertEqual(httpRequest?.method, .post)
        XCTAssertEqual(httpRequest?.headers["Content-Type"], "application/json")
        XCTAssertEqual(httpRequest?.bodyAsString(), bodyString)
    }
    
    func testConversionToURLRequest() {
        // Arrange
        let url = "https://api.example.com/users"
        let method = HTTPRequest.Method.post
        let headers = ["Content-Type": "application/json"]
        let bodyString = "{\"username\":\"test\"}"
        let body = bodyString.data(using: .utf8)
        let httpRequest = HTTPRequest(url: url, method: method, headers: headers, body: body)
        
        // Act
        let urlRequest = httpRequest.toURLRequest()
        
        // Assert
        XCTAssertNotNil(urlRequest)
        XCTAssertEqual(urlRequest?.url?.absoluteString, url)
        XCTAssertEqual(urlRequest?.httpMethod, method.rawValue)
        XCTAssertEqual(urlRequest?.allHTTPHeaderFields, headers)
        XCTAssertEqual(urlRequest?.httpBody, body)
    }
    
    func testBodyAsString() {
        // Arrange
        let bodyString = "{\"name\":\"Test\"}"
        let body = bodyString.data(using: .utf8)
        let request = HTTPRequest(
            url: "https://example.com",
            method: .post,
            body: body
        )
        
        // Act
        let result = request.bodyAsString()
        
        // Assert
        XCTAssertEqual(result, bodyString)
    }
    
    func testDecodeBody() {
        // Arrange
        struct TestModel: Codable, Equatable {
            let name: String
            let value: Int
        }
        
        let testModel = TestModel(name: "Test", value: 123)
        let encoder = JSONEncoder()
        let body = try! encoder.encode(testModel)
        let request = HTTPRequest(
            url: "https://example.com",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: body
        )
        
        // Act
        let decodedModel = request.decodeBody(as: TestModel.self)
        
        // Assert
        XCTAssertNotNil(decodedModel)
        XCTAssertEqual(decodedModel, testModel)
    }
    
    func testQueryParameters() {
        // Arrange
        let url = "https://api.example.com/search?q=swift&page=1&limit=20"
        let request = HTTPRequest(url: url, method: .get)
        
        // Act
        let params = request.queryParameters()
        
        // Assert
        XCTAssertEqual(params.count, 3)
        XCTAssertEqual(params["q"], "swift")
        XCTAssertEqual(params["page"], "1")
        XCTAssertEqual(params["limit"], "20")
    }
    
    func testEquatable() {
        // Arrange
        let request1 = HTTPRequest(
            url: "https://api.example.com",
            method: .get,
            headers: ["Accept": "application/json"]
        )
        
        let request2 = HTTPRequest(
            url: "https://api.example.com",
            method: .get,
            headers: ["Accept": "application/json"]
        )
        
        let request3 = HTTPRequest(
            url: "https://api.example.com/different",
            method: .post,
            headers: ["Content-Type": "application/json"]
        )
        
        // Assert
        XCTAssertEqual(request1, request2)
        XCTAssertNotEqual(request1, request3)
    }
    
    func testDescription() {
        // Arrange
        let url = "https://api.example.com/data"
        let method = HTTPRequest.Method.post
        let headers = ["Content-Type": "application/json"]
        let bodyString = "{\"test\":\"value\"}"
        let body = bodyString.data(using: .utf8)
        let request = HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: body
        )
        
        // Act
        let description = request.description
        
        // Assert
        XCTAssertTrue(description.contains("[POST]"))
        XCTAssertTrue(description.contains(url))
        XCTAssertTrue(description.contains("Content-Type"))
        XCTAssertTrue(description.contains("application/json"))
        XCTAssertTrue(description.contains(bodyString))
    }
} 