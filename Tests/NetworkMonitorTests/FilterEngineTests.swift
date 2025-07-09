import XCTest
@testable import NetworkMonitor

final class FilterEngineTests: XCTestCase {
    
    var filterEngine: FilterEngine!
    var sampleSessions: [HTTPSession]!
    
    override func setUpWithError() throws {
        filterEngine = FilterEngine()
        sampleSessions = createSampleSessions()
    }
    
    private func createSampleSessions() -> [HTTPSession] {
        var sessions: [HTTPSession] = []
        
        // 成功レスポンス
        let successRequest = HTTPRequest(url: "https://api.example.com/users", method: .get)
        let successResponse = HTTPResponse(statusCode: 200, headers: ["Content-Type": "application/json"], duration: 0.5)
        let successSession = HTTPSession(request: successRequest, response: successResponse, state: .completed)
        sessions.append(successSession)
        
        // クライアントエラー
        let errorRequest = HTTPRequest(url: "https://api.example.com/users/999", method: .get)
        let errorResponse = HTTPResponse(statusCode: 404, duration: 0.3)
        let errorSession = HTTPSession(request: errorRequest, response: errorResponse, state: .completed)
        sessions.append(errorSession)
        
        // サーバーエラー
        let serverErrorRequest = HTTPRequest(url: "https://api.example.com/posts", method: .post)
        let serverErrorResponse = HTTPResponse(statusCode: 500, duration: 2.0)
        let serverErrorSession = HTTPSession(request: serverErrorRequest, response: serverErrorResponse, state: .completed)
        sessions.append(serverErrorSession)
        
        // 別ホストの成功レスポンス
        let otherHostRequest = HTTPRequest(url: "https://cdn.other.com/images/logo.png", method: .get)
        let otherHostResponse = HTTPResponse(statusCode: 200, headers: ["Content-Type": "image/png"], duration: 1.2)
        let otherHostSession = HTTPSession(request: otherHostRequest, response: otherHostResponse, state: .completed)
        sessions.append(otherHostSession)
        
        // 進行中のセッション（別ホスト）
        let ongoingRequest = HTTPRequest(url: "https://files.another.com/upload", method: .post)
        let ongoingSession = HTTPSession(request: ongoingRequest, state: .sending)
        sessions.append(ongoingSession)
        
        return sessions
    }
    
    // MARK: - Basic Filtering Tests
    
    func testBasicFiltering() throws {
        let criteria = FilterCriteria().statusCategory(.success)
        let filtered = filterEngine.filter(sessions: sampleSessions, using: criteria)
        
        XCTAssertEqual(filtered.count, 2) // 2つの成功レスポンス
        XCTAssertTrue(filtered.allSatisfy { $0.response?.isSuccess == true })
    }
    
    func testEmptyResult() throws {
        let criteria = FilterCriteria().statusCode(999) // 存在しないステータスコード
        let filtered = filterEngine.filter(sessions: sampleSessions, using: criteria)
        
        XCTAssertEqual(filtered.count, 0)
    }
    
    func testNoFilteringCriteria() throws {
        let criteria = FilterCriteria() // 空の条件
        let filtered = filterEngine.filter(sessions: sampleSessions, using: criteria)
        
        XCTAssertEqual(filtered.count, sampleSessions.count)
    }
    
    // MARK: - Multiple Criteria Tests
    
    func testMultipleCriteriaAND() throws {
        let criteria1 = FilterCriteria().host(pattern: "api.example.com")
        let criteria2 = FilterCriteria().statusCategory(.success)
        
        let filtered = filterEngine.filter(
            sessions: sampleSessions,
            using: [criteria1, criteria2],
            operator: .and
        )
        
        XCTAssertEqual(filtered.count, 1) // api.example.comの成功レスポンスのみ
    }
    
    func testMultipleCriteriaOR() throws {
        let criteria1 = FilterCriteria().statusCode(404)
        let criteria2 = FilterCriteria().statusCode(500)
        
        let filtered = filterEngine.filter(
            sessions: sampleSessions,
            using: [criteria1, criteria2],
            operator: .or
        )
        
        XCTAssertEqual(filtered.count, 2) // 404と500のレスポンス
    }
    
    func testEmptyCriteriaList() throws {
        let filtered = filterEngine.filter(
            sessions: sampleSessions,
            using: [],
            operator: .and
        )
        
        XCTAssertEqual(filtered.count, sampleSessions.count)
    }
    
    // MARK: - Advanced Filtering Tests
    
    func testCategorizeFiltering() throws {
        let groupCriteria = [
            "success": FilterCriteria.successOnly(),
            "errors": FilterCriteria.errorsOnly(),
            "api_requests": FilterCriteria().host(pattern: "api.example.com")
        ]
        
        let categorized = filterEngine.categorize(sessions: sampleSessions, using: groupCriteria)
        
        XCTAssertEqual(categorized["success"]?.count, 2)
        XCTAssertEqual(categorized["errors"]?.count, 2)
        XCTAssertEqual(categorized["api_requests"]?.count, 3)
    }
    
    func testFilterAndSort() throws {
        let criteria = FilterCriteria().host(pattern: "api.example.com")
        let filtered = filterEngine.filterAndSort(sessions: sampleSessions, using: criteria, ascending: true)
        
        XCTAssertEqual(filtered.count, 3)
        
        // 時系列順にソートされているか確認
        for i in 1..<filtered.count {
            XCTAssertLessThanOrEqual(filtered[i-1].startTime, filtered[i].startTime)
        }
    }
    
    func testFilterAndSortDescending() throws {
        let criteria = FilterCriteria().host(pattern: "api.example.com")
        let filtered = filterEngine.filterAndSort(sessions: sampleSessions, using: criteria, ascending: false)
        
        XCTAssertEqual(filtered.count, 3)
        
        // 降順でソートされているか確認
        for i in 1..<filtered.count {
            XCTAssertGreaterThanOrEqual(filtered[i-1].startTime, filtered[i].startTime)
        }
    }
    
    func testPaginationFiltering() throws {
        let criteria = FilterCriteria() // すべてのセッション
        
        // 1ページ目（2件ずつ）
        let page0 = filterEngine.filterWithPagination(sessions: sampleSessions, using: criteria, page: 0, pageSize: 2)
        XCTAssertEqual(page0.count, 2)
        
        // 2ページ目
        let page1 = filterEngine.filterWithPagination(sessions: sampleSessions, using: criteria, page: 1, pageSize: 2)
        XCTAssertEqual(page1.count, 2)
        
        // 3ページ目（残り1件）
        let page2 = filterEngine.filterWithPagination(sessions: sampleSessions, using: criteria, page: 2, pageSize: 2)
        XCTAssertEqual(page2.count, 1)
        
        // 4ページ目（空）
        let page3 = filterEngine.filterWithPagination(sessions: sampleSessions, using: criteria, page: 3, pageSize: 2)
        XCTAssertEqual(page3.count, 0)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceTracking() throws {
        filterEngine.isPerformanceTrackingEnabled = true
        
        let criteria = FilterCriteria().statusCategory(.success)
        let filtered = filterEngine.filter(sessions: sampleSessions, using: criteria)
        
        XCTAssertNotNil(filterEngine.lastFilteringStats)
        XCTAssertEqual(filterEngine.lastFilteringStats?.totalSessions, sampleSessions.count)
        XCTAssertEqual(filterEngine.lastFilteringStats?.filteredSessions, filtered.count)
        XCTAssertGreaterThan(filterEngine.lastFilteringStats?.processingTime ?? 0, 0)
    }
    
    func testFilteringStatistics() throws {
        let criteria = FilterCriteria().statusCategory(.success)
        let stats = filterEngine.getFilteringStatistics(sessions: sampleSessions, using: criteria)
        
        XCTAssertEqual(stats.totalSessions, sampleSessions.count)
        XCTAssertEqual(stats.filteredSessions, 2)
        XCTAssertGreaterThan(stats.processingTime, 0)
        XCTAssertEqual(stats.filteringRatio, 2.0 / Double(sampleSessions.count), accuracy: 0.001)
    }
    
    // MARK: - Convenience Methods Tests
    
    func testConvenienceFilterSuccessOnly() throws {
        let filtered = filterEngine.filterSuccessOnly(sessions: sampleSessions)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.response?.isSuccess == true })
    }
    
    func testConvenienceFilterErrorsOnly() throws {
        let filtered = filterEngine.filterErrorsOnly(sessions: sampleSessions)
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.response?.isError == true })
    }
    
    func testConvenienceFilterByHost() throws {
        let filtered = filterEngine.filterByHost(sessions: sampleSessions, host: "api.example.com")
        XCTAssertEqual(filtered.count, 3)
        XCTAssertTrue(filtered.allSatisfy { $0.host?.contains("api.example.com") == true })
    }
    
    func testConvenienceFilterSlowRequests() throws {
        let filtered = filterEngine.filterSlowRequests(sessions: sampleSessions, threshold: 1.0)
        XCTAssertEqual(filtered.count, 2) // 1.2秒と2.0秒のレスポンス
    }
    
    // MARK: - Summary Statistics Tests
    
    func testGenerateSummaryStatistics() throws {
        let stats = filterEngine.generateSummaryStatistics(for: sampleSessions)
        
        XCTAssertEqual(stats["total"] as? Int, 5)
        XCTAssertEqual(stats["completed"] as? Int, 4)
        XCTAssertEqual(stats["failed"] as? Int, 0)
        XCTAssertEqual(stats["cancelled"] as? Int, 0)
        
        let methodCounts = stats["methodCounts"] as? [String: Int]
        XCTAssertEqual(methodCounts?["GET"], 3)
        XCTAssertEqual(methodCounts?["POST"], 2)
        
        let statusCodeCounts = stats["statusCodeCounts"] as? [Int: Int]
        XCTAssertEqual(statusCodeCounts?[200], 2)
        XCTAssertEqual(statusCodeCounts?[404], 1)
        XCTAssertEqual(statusCodeCounts?[500], 1)
        
        let hostCounts = stats["hostCounts"] as? [String: Int]
        XCTAssertEqual(hostCounts?["api.example.com"], 3)
        XCTAssertEqual(hostCounts?["cdn.other.com"], 1)
    }
    
    func testGenerateSummaryStatisticsEmptyArray() throws {
        let stats = filterEngine.generateSummaryStatistics(for: [])
        XCTAssertEqual(stats["total"] as? Int, 0)
    }
    
    // MARK: - Filter Management Tests
    
    func testActiveFilterManagement() throws {
        XCTAssertNil(filterEngine.activeFilter)
        
        let criteria = FilterCriteria().statusCategory(.success)
        _ = filterEngine.filter(sessions: sampleSessions, using: criteria)
        
        XCTAssertNotNil(filterEngine.activeFilter)
        
        filterEngine.clearActiveFilter()
        XCTAssertNil(filterEngine.activeFilter)
    }
    
    func testStatisticsReset() throws {
        filterEngine.isPerformanceTrackingEnabled = true
        
        let criteria = FilterCriteria().statusCategory(.success)
        _ = filterEngine.filter(sessions: sampleSessions, using: criteria)
        
        XCTAssertNotNil(filterEngine.lastFilteringStats)
        
        filterEngine.resetStatistics()
        XCTAssertNil(filterEngine.lastFilteringStats)
    }
}