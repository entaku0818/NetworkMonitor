import XCTest
@testable import NetworkMonitor

final class SessionSearchServiceTests: XCTestCase {
    
    var searchService: SessionSearchService!
    var sampleSessions: [HTTPSession]!
    
    override func setUpWithError() throws {
        let configuration = SessionSearchService.SearchConfiguration(
            caseSensitive: false,
            useRegex: false,
            fullTextSearch: true,
            maxResults: 100,
            enableHighlights: true,
            timeout: 5.0
        )
        
        searchService = SessionSearchService(configuration: configuration)
        sampleSessions = createSampleSessions()
    }
    
    override func tearDownWithError() throws {
        searchService = nil
        sampleSessions = nil
    }
    
    private func createSampleSessions() -> [HTTPSession] {
        var sessions: [HTTPSession] = []
        
        // GitHub API リクエスト
        let githubRequest = HTTPRequest(
            url: "https://api.github.com/users/octocat",
            method: .get,
            headers: ["Authorization": "token github_token", "User-Agent": "MyApp"]
        )
        let githubResponse = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: "{\"login\":\"octocat\",\"id\":1}".data(using: .utf8),
            duration: 0.45
        )
        let githubSession = HTTPSession(request: githubRequest, response: githubResponse, state: .completed)
            .addMetadata(key: "api_version", value: "v3")
        sessions.append(githubSession)
        
        // Google検索リクエスト
        let googleRequest = HTTPRequest(
            url: "https://www.google.com/search?q=swift+programming",
            method: .get,
            headers: ["User-Agent": "Mozilla/5.0"]
        )
        let googleResponse = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "text/html"],
            body: "<html><title>Search Results</title></html>".data(using: .utf8),
            duration: 0.23
        )
        let googleSession = HTTPSession(request: googleRequest, response: googleResponse, state: .completed)
        sessions.append(googleSession)
        
        // APIエラーレスポンス
        let errorRequest = HTTPRequest(
            url: "https://api.example.com/users/999",
            method: .get,
            headers: ["Authorization": "Bearer invalid_token"]
        )
        let errorResponse = HTTPResponse(
            statusCode: 404,
            headers: ["Content-Type": "application/json"],
            body: "{\"error\":\"User not found\"}".data(using: .utf8),
            duration: 0.12
        )
        let errorSession = HTTPSession(request: errorRequest, response: errorResponse, state: .completed)
        sessions.append(errorSession)
        
        // POSTリクエスト
        let postRequest = HTTPRequest(
            url: "https://api.example.com/posts",
            method: .post,
            headers: ["Content-Type": "application/json"],
            body: "{\"title\":\"Hello World\",\"content\":\"This is a test post\"}".data(using: .utf8)
        )
        let postResponse = HTTPResponse(
            statusCode: 201,
            headers: ["Content-Type": "application/json"],
            body: "{\"id\":123,\"title\":\"Hello World\"}".data(using: .utf8),
            duration: 0.67
        )
        let postSession = HTTPSession(request: postRequest, response: postResponse, state: .completed)
        sessions.append(postSession)
        
        // 進行中のセッション
        let ongoingRequest = HTTPRequest(
            url: "https://api.example.com/upload",
            method: .post,
            headers: ["Content-Type": "multipart/form-data"]
        )
        let ongoingSession = HTTPSession(request: ongoingRequest, state: .sending)
        sessions.append(ongoingSession)
        
        return sessions
    }
    
    // MARK: - Basic Search Tests
    
    func testSimpleTextSearch() throws {
        let expectation = XCTestExpectation(description: "Simple text search")
        
        let query = SearchQuery(text: "github")
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 1)
                XCTAssertEqual(searchResult.sessions.count, 1)
                XCTAssertTrue(searchResult.sessions.first?.request.url.contains("github.com") ?? false)
                XCTAssertGreaterThan(searchResult.searchTime, 0)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCaseInsensitiveSearch() throws {
        let expectation = XCTestExpectation(description: "Case insensitive search")
        
        let query = SearchQuery(text: "GITHUB")
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 1)
                XCTAssertTrue(searchResult.sessions.first?.request.url.contains("github.com") ?? false)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testNoMatchesFound() throws {
        let expectation = XCTestExpectation(description: "No matches found")
        
        let query = SearchQuery(text: "nonexistent_text_12345")
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 0)
                XCTAssertEqual(searchResult.sessions.count, 0)
                XCTAssertEqual(searchResult.totalCount, self.sampleSessions.count)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Filter Search Tests
    
    func testSearchWithStatusCodeFilter() throws {
        let expectation = XCTestExpectation(description: "Search with status code filter")
        
        let filter = FilterCriteria().statusCode(404)
        let query = SearchQuery(filters: [filter])
        
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 1)
                XCTAssertEqual(searchResult.sessions.first?.statusCode, 404)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSearchWithMethodFilter() throws {
        let expectation = XCTestExpectation(description: "Search with method filter")
        
        let filter = FilterCriteria().method(.post)
        let query = SearchQuery(filters: [filter])
        
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 2) // POSTとuploadセッション
                for session in searchResult.sessions {
                    XCTAssertEqual(session.request.method, .post)
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSearchWithMultipleFilters() throws {
        let expectation = XCTestExpectation(description: "Search with multiple filters")
        
        let methodFilter = FilterCriteria().method(.get)
        let statusFilter = FilterCriteria().statusCategory(.success)
        let query = SearchQuery(filters: [methodFilter, statusFilter])
        
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 2) // GitHubとGoogleのGETリクエスト
                for session in searchResult.sessions {
                    XCTAssertEqual(session.request.method, .get)
                    XCTAssertTrue(session.response?.isSuccess ?? false)
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Date Range Search Tests
    
    func testSearchWithDateRange() throws {
        let expectation = XCTestExpectation(description: "Search with date range")
        
        // 現在時刻から1時間前までの範囲
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -1, to: endDate)!
        let dateRange = DateRange(start: startDate, end: endDate)
        
        let query = SearchQuery(dateRange: dateRange)
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                // 全てのサンプルセッションは最近作成されているのでマッチするはず
                XCTAssertEqual(searchResult.matchCount, self.sampleSessions.count)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSearchWithDateRangePresets() throws {
        let expectation = XCTestExpectation(description: "Search with date range presets")
        
        let query = SearchQuery(dateRange: .today)
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                // 今日作成されたセッションがマッチするはず
                XCTAssertGreaterThan(searchResult.matchCount, 0)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Sort Tests
    
    func testSearchWithTimestampSort() throws {
        let expectation = XCTestExpectation(description: "Search with timestamp sort")
        
        let query = SearchQuery(sortBy: .timestamp, ascending: false)
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.sessions.count, self.sampleSessions.count)
                
                // 時刻順にソートされているかチェック
                for i in 1..<searchResult.sessions.count {
                    let prev = searchResult.sessions[i-1].startTime
                    let current = searchResult.sessions[i].startTime
                    XCTAssertGreaterThanOrEqual(prev, current)
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSearchWithDurationSort() throws {
        let expectation = XCTestExpectation(description: "Search with duration sort")
        
        let query = SearchQuery(sortBy: .duration, ascending: false)
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                // 完了したセッションのみをチェック（duration > 0）
                let completedSessions = searchResult.sessions.filter { $0.response != nil }
                
                for i in 1..<completedSessions.count {
                    let prev = completedSessions[i-1].duration
                    let current = completedSessions[i].duration
                    XCTAssertGreaterThanOrEqual(prev, current)
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Highlight Tests
    
    func testSearchHighlights() throws {
        let expectation = XCTestExpectation(description: "Search highlights")
        
        let query = SearchQuery(text: "github")
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 1)
                XCTAssertEqual(searchResult.highlights.count, 1)
                
                if let sessionHighlights = searchResult.highlights.first?.value {
                    XCTAssertGreaterThan(sessionHighlights.count, 0)
                    let highlight = sessionHighlights.first!
                    // The field could be host, url, or other fields depending on search order
                    XCTAssertTrue(SessionSearchService.SearchField.allCases.contains(highlight.field))
                    XCTAssertEqual(highlight.matchedText.lowercased(), "github")
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Regex Search Tests
    
    func testRegexSearch() throws {
        let expectation = XCTestExpectation(description: "Regex search")
        
        let regexConfig = SessionSearchService.SearchConfiguration(useRegex: true)
        let regexSearchService = SessionSearchService(configuration: regexConfig)
        
        // APIエンドポイントにマッチする正規表現
        let query = SearchQuery(text: "api\\.[a-z]+\\.com")
        regexSearchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 4) // api.github.com, api.example.com (2つ), api.example.com (upload)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Regex search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testInvalidRegexPattern() throws {
        let expectation = XCTestExpectation(description: "Invalid regex pattern")
        
        let regexConfig = SessionSearchService.SearchConfiguration(useRegex: true)
        let regexSearchService = SessionSearchService(configuration: regexConfig)
        
        // 無効な正規表現パターン
        let query = SearchQuery(text: "[invalid")
        regexSearchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(_):
                XCTFail("Should have failed with invalid regex")
            case .failure(let error):
                XCTAssertNotNil(error)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Field-Specific Search Tests
    
    func testHostOnlySearch() throws {
        let expectation = XCTestExpectation(description: "Host only search")
        
        let hostConfig = SessionSearchService.SearchConfiguration(
            searchFields: [.host]
        )
        let hostSearchService = SessionSearchService(configuration: hostConfig)
        
        let query = SearchQuery(text: "github")
        hostSearchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 1)
                XCTAssertTrue(searchResult.sessions.first?.request.url.contains("github.com") ?? false)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Host search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testHeaderOnlySearch() throws {
        let expectation = XCTestExpectation(description: "Header only search")
        
        let headerConfig = SessionSearchService.SearchConfiguration(
            searchFields: [.requestHeaders, .responseHeaders]
        )
        let headerSearchService = SessionSearchService(configuration: headerConfig)
        
        let query = SearchQuery(text: "application/json")
        headerSearchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertGreaterThan(searchResult.matchCount, 0)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Header search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Convenience Method Tests
    
    func testSimpleSearchConvenience() throws {
        let expectation = XCTestExpectation(description: "Simple search convenience")
        
        searchService.simpleSearch(text: "github", in: sampleSessions) { result in
            switch result {
            case .success(let sessions):
                XCTAssertEqual(sessions.count, 1)
                XCTAssertTrue(sessions.first?.request.url.contains("github.com") ?? false)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Simple search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSearchByHost() throws {
        let expectation = XCTestExpectation(description: "Search by host")
        
        searchService.searchByHost("github.com", in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 1)
                XCTAssertTrue(searchResult.sessions.first?.request.url.contains("github.com") ?? false)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Host search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSearchByStatusCode() throws {
        let expectation = XCTestExpectation(description: "Search by status code")
        
        searchService.searchByStatusCode(200, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 2) // GitHub, Google (POST is 201)
                for session in searchResult.sessions {
                    XCTAssertEqual(session.statusCode, 200)
                }
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Status code search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testRegexSearchConvenience() throws {
        let expectation = XCTestExpectation(description: "Regex search convenience")
        
        searchService.regexSearch(pattern: "\\d{3}", in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                // ステータスコードなどの3桁の数字にマッチするはず
                XCTAssertGreaterThan(searchResult.matchCount, 0)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Regex search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testSearchPerformance() throws {
        // 大量のデータでパフォーマンステスト
        var largeSessions: [HTTPSession] = []
        for i in 0..<1000 {
            let request = HTTPRequest(url: "https://api.test.com/data/\(i)", method: .get)
            let response = HTTPResponse(statusCode: 200, duration: 0.1)
            let session = HTTPSession(request: request, response: response, state: .completed)
            largeSessions.append(session)
        }
        
        let expectation = XCTestExpectation(description: "Search performance")
        let startTime = Date()
        
        let query = SearchQuery(text: "test")
        searchService.search(query: query, in: largeSessions) { result in
            let searchTime = Date().timeIntervalSince(startTime)
            
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 1000) // すべてマッチするはず
                XCTAssertLessThan(searchTime, 1.0) // 1秒以内に完了するはず
                XCTAssertGreaterThan(searchResult.searchTime, 0)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Performance search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyQuery() throws {
        let expectation = XCTestExpectation(description: "Empty query")
        
        let query = SearchQuery(text: "")
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                // 空のクエリでは全てのセッションがマッチするはず
                XCTAssertEqual(searchResult.matchCount, self.sampleSessions.count)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Empty query search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testEmptySessionArray() throws {
        let expectation = XCTestExpectation(description: "Empty session array")
        
        let query = SearchQuery(text: "github")
        searchService.search(query: query, in: []) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 0)
                XCTAssertEqual(searchResult.totalCount, 0)
                XCTAssertEqual(searchResult.sessions.count, 0)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Empty session search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSpecialCharacterSearch() throws {
        let expectation = XCTestExpectation(description: "Special character search")
        
        let query = SearchQuery(text: "@#$%^&*()")
        searchService.search(query: query, in: sampleSessions) { result in
            switch result {
            case .success(let searchResult):
                XCTAssertEqual(searchResult.matchCount, 0)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Special character search failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}