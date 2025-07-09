import XCTest
@testable import NetworkMonitor

final class InMemorySessionStorageTests: XCTestCase {
    
    var storage: InMemorySessionStorage!
    var sampleSessions: [HTTPSession]!
    
    override func setUpWithError() throws {
        let configuration = InMemorySessionStorage.Configuration(
            maxSessions: 50,
            autoCleanup: false, // テスト中は手動制御
            retentionPeriod: 60, // 1分
            maxMemoryUsage: 10 * 1024 * 1024 // 10MB
        )
        
        storage = InMemorySessionStorage(configuration: configuration)
        sampleSessions = createSampleSessions()
    }
    
    override func tearDownWithError() throws {
        storage = nil
        sampleSessions = nil
    }
    
    private func createSampleSessions() -> [HTTPSession] {
        var sessions: [HTTPSession] = []
        
        // 成功レスポンス
        let successRequest = HTTPRequest(url: "https://api.example.com/users", method: .get)
        let successResponse = HTTPResponse(statusCode: 200, headers: ["Content-Type": "application/json"], duration: 0.5)
        let successSession = HTTPSession(request: successRequest, response: successResponse, state: .completed)
        sessions.append(successSession)
        
        // エラーレスポンス
        let errorRequest = HTTPRequest(url: "https://api.example.com/users/999", method: .get)
        let errorResponse = HTTPResponse(statusCode: 404, duration: 0.3)
        let errorSession = HTTPSession(request: errorRequest, response: errorResponse, state: .completed)
        sessions.append(errorSession)
        
        // 進行中のセッション
        let ongoingRequest = HTTPRequest(url: "https://api.example.com/upload", method: .post)
        let ongoingSession = HTTPSession(request: ongoingRequest, state: .sending)
        sessions.append(ongoingSession)
        
        return sessions
    }
    
    // MARK: - Basic Storage Tests
    
    func testSaveAndLoadSingleSession() throws {
        let expectation = XCTestExpectation(description: "Save and load session")
        let session = sampleSessions[0]
        
        storage.save(session: session) { result in
            switch result {
            case .success():
                self.storage.load(sessionID: session.id) { loadResult in
                    switch loadResult {
                    case .success(let loadedSession):
                        XCTAssertNotNil(loadedSession)
                        XCTAssertEqual(loadedSession?.id, session.id)
                        XCTAssertEqual(loadedSession?.url, session.url)
                        XCTAssertEqual(loadedSession?.httpMethod, session.httpMethod)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Failed to load session: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save session: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSaveAndLoadMultipleSessions() throws {
        let expectation = XCTestExpectation(description: "Save and load multiple sessions")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                self.storage.loadAll { loadResult in
                    switch loadResult {
                    case .success(let loadedSessions):
                        XCTAssertEqual(loadedSessions.count, self.sampleSessions.count)
                        
                        // IDのセットが一致することを確認
                        let originalIDs = Set(self.sampleSessions.map { $0.id })
                        let loadedIDs = Set(loadedSessions.map { $0.id })
                        XCTAssertEqual(originalIDs, loadedIDs)
                        
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Failed to load sessions: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testLoadNonexistentSession() throws {
        let expectation = XCTestExpectation(description: "Load nonexistent session")
        let nonexistentID = UUID()
        
        storage.load(sessionID: nonexistentID) { result in
            switch result {
            case .success(let session):
                XCTAssertNil(session)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Filtering Tests
    
    func testLoadWithFilter() throws {
        let expectation = XCTestExpectation(description: "Load with filter")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                let criteria = FilterCriteria().statusCategory(.success)
                self.storage.load(matching: criteria) { loadResult in
                    switch loadResult {
                    case .success(let filteredSessions):
                        XCTAssertEqual(filteredSessions.count, 1)
                        XCTAssertEqual(filteredSessions.first?.statusCode, 200)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Failed to load filtered sessions: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Deletion Tests
    
    func testDeleteSingleSession() throws {
        let expectation = XCTestExpectation(description: "Delete single session")
        let session = sampleSessions[0]
        
        storage.save(session: session) { result in
            switch result {
            case .success():
                self.storage.delete(sessionID: session.id) { deleteResult in
                    switch deleteResult {
                    case .success():
                        self.storage.load(sessionID: session.id) { loadResult in
                            switch loadResult {
                            case .success(let loadedSession):
                                XCTAssertNil(loadedSession)
                                expectation.fulfill()
                            case .failure(let error):
                                XCTFail("Unexpected error: \(error)")
                            }
                        }
                    case .failure(let error):
                        XCTFail("Failed to delete session: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save session: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDeleteAll() throws {
        let expectation = XCTestExpectation(description: "Delete all sessions")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                self.storage.deleteAll { deleteResult in
                    switch deleteResult {
                    case .success():
                        self.storage.loadAll { loadResult in
                            switch loadResult {
                            case .success(let sessions):
                                XCTAssertEqual(sessions.count, 0)
                                expectation.fulfill()
                            case .failure(let error):
                                XCTFail("Failed to load sessions: \(error)")
                            }
                        }
                    case .failure(let error):
                        XCTFail("Failed to delete all sessions: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDeleteWithFilter() throws {
        let expectation = XCTestExpectation(description: "Delete with filter")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                let criteria = FilterCriteria().statusCode(404)
                self.storage.delete(matching: criteria) { deleteResult in
                    switch deleteResult {
                    case .success(let deletedCount):
                        XCTAssertEqual(deletedCount, 1)
                        
                        self.storage.loadAll { loadResult in
                            switch loadResult {
                            case .success(let remainingSessions):
                                XCTAssertEqual(remainingSessions.count, 2) // 元の3つから1つ削除
                                expectation.fulfill()
                            case .failure(let error):
                                XCTFail("Failed to load remaining sessions: \(error)")
                            }
                        }
                    case .failure(let error):
                        XCTFail("Failed to delete sessions: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Statistics Tests
    
    func testCount() throws {
        let expectation = XCTestExpectation(description: "Count sessions")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                self.storage.count { countResult in
                    switch countResult {
                    case .success(let count):
                        XCTAssertEqual(count, self.sampleSessions.count)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Failed to count sessions: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testStorageSize() throws {
        let expectation = XCTestExpectation(description: "Get storage size")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                self.storage.storageSize { sizeResult in
                    switch sizeResult {
                    case .success(let size):
                        XCTAssertGreaterThan(size, 0)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Failed to get storage size: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryLimit() throws {
        let expectation = XCTestExpectation(description: "Memory limit enforcement")
        
        // 小さなメモリ制限で設定
        let smallConfig = InMemorySessionStorage.Configuration(
            maxSessions: 2,
            autoCleanup: false
        )
        let limitedStorage = InMemorySessionStorage(configuration: smallConfig)
        
        // 最初の2つのセッションは保存できるはず
        limitedStorage.save(sessions: Array(sampleSessions.prefix(2))) { result in
            switch result {
            case .success():
                // 3つ目のセッションを追加しようとするとエラーになるはず
                limitedStorage.save(session: self.sampleSessions[2]) { saveResult in
                    switch saveResult {
                    case .success():
                        XCTFail("Should have failed due to memory limit")
                    case .failure(let error):
                        if let memoryError = error as? InMemorySessionStorage.MemoryStorageError {
                            XCTAssertEqual(memoryError, .memoryLimitExceeded)
                        }
                        expectation.fulfill()
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save initial sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMemoryStatistics() throws {
        let expectation = XCTestExpectation(description: "Memory statistics")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                let stats = self.storage.getMemoryStatistics()
                
                XCTAssertEqual(stats.sessionCount, self.sampleSessions.count)
                XCTAssertGreaterThan(stats.estimatedMemoryUsage, 0)
                XCTAssertGreaterThan(stats.sessionCountRatio, 0)
                XCTAssertLessThanOrEqual(stats.sessionCountRatio, 1.0)
                XCTAssertFalse(stats.humanReadableMemoryUsage.isEmpty)
                
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed to save sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Cleanup Tests
    
    func testManualCleanup() throws {
        let expectation = XCTestExpectation(description: "Manual cleanup")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                self.storage.performManualCleanup { cleanupResult in
                    switch cleanupResult {
                    case .success(let cleanedCount):
                        // 保持期間内なので何も削除されないはず
                        XCTAssertEqual(cleanedCount, 0)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Failed to perform cleanup: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentAccess() throws {
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 3
        
        let session1 = sampleSessions[0]
        let session2 = sampleSessions[1]
        let session3 = sampleSessions[2]
        
        // 同時に複数のセッションを保存
        storage.save(session: session1) { result in
            switch result {
            case .success():
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed to save session1: \(error)")
            }
        }
        
        storage.save(session: session2) { result in
            switch result {
            case .success():
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed to save session2: \(error)")
            }
        }
        
        storage.save(session: session3) { result in
            switch result {
            case .success():
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Failed to save session3: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // 全てが保存されていることを確認
        let countExpectation = XCTestExpectation(description: "Verify count")
        storage.count { result in
            switch result {
            case .success(let count):
                XCTAssertEqual(count, 3)
                countExpectation.fulfill()
            case .failure(let error):
                XCTFail("Failed to count: \(error)")
            }
        }
        
        wait(for: [countExpectation], timeout: 5.0)
    }
    
    // MARK: - Recently Accessed Sessions Tests
    
    func testGetRecentlyAccessedSessions() throws {
        let expectation = XCTestExpectation(description: "Get recently accessed sessions")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                // 最初のセッションにアクセス
                self.storage.load(sessionID: self.sampleSessions[0].id) { _ in
                    // 最後のセッションにアクセス
                    self.storage.load(sessionID: self.sampleSessions[2].id) { _ in
                        // 最近アクセスされたセッションを取得
                        self.storage.getRecentlyAccessedSessions(count: 2) { recentResult in
                            switch recentResult {
                            case .success(let recentSessions):
                                XCTAssertEqual(recentSessions.count, 2)
                                // 最近アクセスされた順序であることを確認
                                let recentIDs = recentSessions.map { $0.id }
                                XCTAssertTrue(recentIDs.contains(self.sampleSessions[0].id))
                                XCTAssertTrue(recentIDs.contains(self.sampleSessions[2].id))
                                expectation.fulfill()
                            case .failure(let error):
                                XCTFail("Failed to get recent sessions: \(error)")
                            }
                        }
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptySessionsList() throws {
        let expectation = XCTestExpectation(description: "Handle empty sessions list")
        
        storage.save(sessions: []) { result in
            switch result {
            case .success():
                self.storage.loadAll { loadResult in
                    switch loadResult {
                    case .success(let sessions):
                        XCTAssertEqual(sessions.count, 0)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save empty sessions: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSessionUpdate() throws {
        let expectation = XCTestExpectation(description: "Session update")
        let originalSession = sampleSessions[0]
        
        storage.save(session: originalSession) { result in
            switch result {
            case .success():
                // 同じIDで別の状態のセッションを保存（更新）
                let updatedSession = originalSession.completed(
                    response: HTTPResponse(statusCode: 201, duration: 1.0),
                    endTime: Date()
                )
                
                self.storage.save(session: updatedSession) { updateResult in
                    switch updateResult {
                    case .success():
                        self.storage.load(sessionID: originalSession.id) { loadResult in
                            switch loadResult {
                            case .success(let loadedSession):
                                XCTAssertNotNil(loadedSession)
                                XCTAssertEqual(loadedSession?.state, .completed)
                                XCTAssertEqual(loadedSession?.statusCode, 201)
                                expectation.fulfill()
                            case .failure(let error):
                                XCTFail("Failed to load updated session: \(error)")
                            }
                        }
                    case .failure(let error):
                        XCTFail("Failed to update session: \(error)")
                    }
                }
            case .failure(let error):
                XCTFail("Failed to save original session: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}