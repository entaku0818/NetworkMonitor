import XCTest
@testable import NetworkMonitor

final class FilterCriteriaTests: XCTestCase {
    
    var sampleRequest: HTTPRequest!
    var sampleResponse: HTTPResponse!
    var sampleSession: HTTPSession!
    
    override func setUpWithError() throws {
        // テスト用のサンプルデータを作成
        sampleRequest = HTTPRequest(
            url: "https://api.example.com/users/123",
            method: .get,
            headers: ["Content-Type": "application/json"],
            body: nil
        )
        
        sampleResponse = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data("{\"id\": 123}".utf8),
            duration: 1.5
        )
        
        sampleSession = HTTPSession(
            request: sampleRequest,
            response: sampleResponse,
            state: .completed
        )
    }
    
    // MARK: - Basic Filter Tests
    
    func testURLFilter() throws {
        let criteria = FilterCriteria().url(pattern: "api.example.com")
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria().url(pattern: "other.com")
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testHostFilter() throws {
        let criteria = FilterCriteria().host(pattern: "api.example.com")
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria().host(pattern: "other.com")
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testPathFilter() throws {
        let criteria = FilterCriteria().path(pattern: "/users/")
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria().path(pattern: "/posts/")
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testMethodFilter() throws {
        let criteria = FilterCriteria().method(.get)
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria().method(.post)
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testStatusCodeFilter() throws {
        let criteria = FilterCriteria().statusCode(200)
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria().statusCode(404)
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testStatusCodeRangeFilter() throws {
        let criteria = FilterCriteria().statusCodeRange(200..<300)
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria().statusCodeRange(400..<500)
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testStatusCategoryFilter() throws {
        let criteria = FilterCriteria().statusCategory(.success)
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria().statusCategory(.clientError)
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testContentTypeFilter() throws {
        let criteria = FilterCriteria().contentType("application/json")
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria().contentType("text/html")
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testDurationFilter() throws {
        let criteria = FilterCriteria().duration(min: 0.0, max: 10.0)
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria().duration(min: 10.0, max: 20.0)
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    // MARK: - Logical Operator Tests
    
    func testAndOperator() throws {
        // 両方の条件を満たす場合
        let criteria = FilterCriteria()
            .host(pattern: "api.example.com")
            .statusCode(200, logicalOperator: .and)
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        // 一方の条件を満たさない場合
        let criteria2 = FilterCriteria()
            .host(pattern: "api.example.com")
            .statusCode(404, logicalOperator: .and)
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testOrOperator() throws {
        // 片方の条件を満たす場合
        let criteria = FilterCriteria()
            .host(pattern: "other.com")
            .statusCode(200, logicalOperator: .or)
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        // 両方の条件を満たさない場合
        let criteria2 = FilterCriteria()
            .host(pattern: "other.com")
            .statusCode(404, logicalOperator: .or)
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testComplexLogicalCombination() throws {
        // (host = "api.example.com" AND status = 200) OR method = POST
        let criteria = FilterCriteria()
            .host(pattern: "api.example.com")
            .statusCode(200, logicalOperator: .and)
            .method(.post, logicalOperator: .or)
        XCTAssertTrue(criteria.matches(session: sampleSession))
    }
    
    // MARK: - Regex Tests
    
    func testRegexURLFilter() throws {
        let criteria = FilterCriteria().url(pattern: ".*\\.example\\.com.*", isRegex: true)
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria().url(pattern: ".*\\.other\\.com.*", isRegex: true)
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testInvalidRegex() throws {
        // 無効な正規表現の場合、文字列一致にフォールバック
        let criteria = FilterCriteria().url(pattern: "[invalid", isRegex: true)
        XCTAssertFalse(criteria.matches(session: sampleSession))
    }
    
    // MARK: - Predefined Filter Tests
    
    func testSuccessOnlyFilter() throws {
        let criteria = FilterCriteria.successOnly()
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        // エラーレスポンスのセッションを作成
        let errorResponse = HTTPResponse(statusCode: 404)
        let errorSession = HTTPSession(request: sampleRequest, response: errorResponse, state: .completed)
        XCTAssertFalse(criteria.matches(session: errorSession))
    }
    
    func testErrorsOnlyFilter() throws {
        let criteria = FilterCriteria.errorsOnly()
        XCTAssertFalse(criteria.matches(session: sampleSession))
        
        // エラーレスポンスのセッションを作成
        let errorResponse = HTTPResponse(statusCode: 404)
        let errorSession = HTTPSession(request: sampleRequest, response: errorResponse, state: .completed)
        XCTAssertTrue(criteria.matches(session: errorSession))
    }
    
    func testHostFilter_Predefined() throws {
        let criteria = FilterCriteria.host("api.example.com")
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria.host("other.com")
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testSlowRequestsFilter() throws {
        let criteria = FilterCriteria.slowRequests(threshold: 0.1)
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        let criteria2 = FilterCriteria.slowRequests(threshold: 10.0)
        XCTAssertFalse(criteria2.matches(session: sampleSession))
    }
    
    func testJSONOnlyFilter() throws {
        let criteria = FilterCriteria.jsonOnly()
        XCTAssertTrue(criteria.matches(session: sampleSession))
        
        // HTMLレスポンスのセッションを作成
        let htmlResponse = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/html"]
        )
        let htmlSession = HTTPSession(request: sampleRequest, response: htmlResponse, state: .completed)
        XCTAssertFalse(criteria.matches(session: htmlSession))
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyFilter() throws {
        let criteria = FilterCriteria()
        XCTAssertTrue(criteria.matches(session: sampleSession))
    }
    
    func testNilResponseSession() throws {
        let sessionWithoutResponse = HTTPSession(request: sampleRequest, state: .sending)
        
        let criteria = FilterCriteria().statusCode(200)
        XCTAssertFalse(criteria.matches(session: sessionWithoutResponse))
    }
    
    func testMetadataFilter() throws {
        let sessionWithMetadata = sampleSession
            .addMetadata(key: "userId", value: "123")
            .addMetadata(key: "apiVersion", value: 2)
        
        // キーの存在確認
        let criteria1 = FilterCriteria().metadata(key: "userId")
        XCTAssertTrue(criteria1.matches(session: sessionWithMetadata))
        
        // 値の一致確認
        let criteria2 = FilterCriteria().metadata(key: "userId", value: .string("123"))
        XCTAssertTrue(criteria2.matches(session: sessionWithMetadata))
        
        // 存在しないキー
        let criteria3 = FilterCriteria().metadata(key: "nonexistent")
        XCTAssertFalse(criteria3.matches(session: sessionWithMetadata))
        
        // 値の不一致
        let criteria4 = FilterCriteria().metadata(key: "userId", value: .string("456"))
        XCTAssertFalse(criteria4.matches(session: sessionWithMetadata))
    }
    
    // MARK: - Utility Tests
    
    func testConditionManagement() throws {
        let criteria = FilterCriteria()
        XCTAssertFalse(criteria.hasConditions)
        XCTAssertEqual(criteria.conditionCount, 0)
        
        criteria.host(pattern: "example.com")
        XCTAssertTrue(criteria.hasConditions)
        XCTAssertEqual(criteria.conditionCount, 1)
        
        criteria.statusCode(200)
        XCTAssertEqual(criteria.conditionCount, 2)
        
        _ = criteria.clearAll()
        XCTAssertFalse(criteria.hasConditions)
        XCTAssertEqual(criteria.conditionCount, 0)
    }
}