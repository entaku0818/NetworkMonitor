import XCTest
@testable import NetworkMonitor

final class SessionStorageTests: XCTestCase {
    
    var storage: FileSessionStorage!
    var tempDirectory: URL!
    var sampleSessions: [HTTPSession]!
    
    override func setUpWithError() throws {
        // テンポラリディレクトリを作成
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetworkMonitorTests")
            .appendingPathComponent(UUID().uuidString)
        
        let configuration = FileSessionStorage.StorageConfiguration(
            baseDirectory: tempDirectory,
            fileFormat: .json,
            maxSessions: 100,
            autoCleanup: false,
            retentionPeriod: 24 * 60 * 60 // 1日
        )
        
        storage = FileSessionStorage(configuration: configuration)
        sampleSessions = createSampleSessions()
    }
    
    override func tearDownWithError() throws {
        // テンポラリディレクトリを削除
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
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
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
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
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            self.storage.delete(sessionID: session.id) { deleteResult in
                switch deleteResult {
                case .success():
                    break // 成功
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                
                self.storage.load(sessionID: session.id) { loadResult in
                    switch loadResult {
                    case .success(let loadedSession):
                        XCTAssertNil(loadedSession)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDeleteAll() throws {
        let expectation = XCTestExpectation(description: "Delete all sessions")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            self.storage.deleteAll { deleteResult in
                switch deleteResult {
                case .success():
                    break // 成功
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                
                self.storage.loadAll { loadResult in
                    switch loadResult {
                    case .success(let sessions):
                        XCTAssertEqual(sessions.count, 0)
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Unexpected error: \(error)")
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testDeleteWithFilter() throws {
        let expectation = XCTestExpectation(description: "Delete with filter")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
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
                            XCTFail("Unexpected error: \(error)")
                        }
                    }
                case .failure(let error):
                    XCTFail("Failed to delete sessions: \(error)")
                }
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
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            self.storage.count { countResult in
                switch countResult {
                case .success(let count):
                    XCTAssertEqual(count, self.sampleSessions.count)
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("Failed to count sessions: \(error)")
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testStorageSize() throws {
        let expectation = XCTestExpectation(description: "Get storage size")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            self.storage.storageSize { sizeResult in
                switch sizeResult {
                case .success(let size):
                    XCTAssertGreaterThan(size, 0)
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("Failed to get storage size: \(error)")
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Export/Import Tests
    
    func testExportAndImport() throws {
        let expectation = XCTestExpectation(description: "Export and import sessions")
        let exportURL = tempDirectory.appendingPathComponent("export.json")
        
        storage.save(sessions: sampleSessions) { result in
            switch result {
            case .success():
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            self.storage.export(sessions: self.sampleSessions, to: exportURL) { exportResult in
                switch exportResult {
                case .success():
                    break // 成功
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
                
                self.storage.importSessions(from: exportURL) { importResult in
                    switch importResult {
                    case .success(let importedSessions):
                        XCTAssertEqual(importedSessions.count, self.sampleSessions.count)
                        
                        // IDのセットが一致することを確認
                        let originalIDs = Set(self.sampleSessions.map { $0.id })
                        let importedIDs = Set(importedSessions.map { $0.id })
                        XCTAssertEqual(originalIDs, importedIDs)
                        
                        expectation.fulfill()
                    case .failure(let error):
                        XCTFail("Failed to import sessions: \(error)")
                    }
                }
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
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            self.storage.loadAll { loadResult in
                switch loadResult {
                case .success(let sessions):
                    XCTAssertEqual(sessions.count, 0)
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testConcurrentAccess() throws {
        let expectation = XCTestExpectation(description: "Handle concurrent access")
        expectation.expectedFulfillmentCount = 3
        
        let session1 = sampleSessions[0]
        let session2 = sampleSessions[1]
        let session3 = sampleSessions[2]
        
        // 同時に複数のセッションを保存
        storage.save(session: session1) { result in
            switch result {
            case .success():
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        storage.save(session: session2) { result in
            switch result {
            case .success():
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
        }
        
        storage.save(session: session3) { result in
            switch result {
            case .success():
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            expectation.fulfill()
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
    
    // MARK: - Configuration Tests
    
    func testDifferentFileFormats() throws {
        let jsonExpectation = XCTestExpectation(description: "JSON format")
        let plistExpectation = XCTestExpectation(description: "Plist format")
        
        let session = sampleSessions[0]
        
        // JSON形式でテスト
        let jsonConfig = FileSessionStorage.StorageConfiguration(
            baseDirectory: tempDirectory.appendingPathComponent("json"),
            fileFormat: .json
        )
        let jsonStorage = FileSessionStorage(configuration: jsonConfig)
        
        jsonStorage.save(session: session) { result in
            switch result {
            case .success():
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            jsonStorage.load(sessionID: session.id) { loadResult in
                switch loadResult {
                case .success(let loadedSession):
                    XCTAssertNotNil(loadedSession)
                    XCTAssertEqual(loadedSession?.id, session.id)
                    jsonExpectation.fulfill()
                case .failure(let error):
                    XCTFail("JSON format failed: \(error)")
                }
            }
        }
        
        // Plist形式でテスト
        let plistConfig = FileSessionStorage.StorageConfiguration(
            baseDirectory: tempDirectory.appendingPathComponent("plist"),
            fileFormat: .binaryPlist
        )
        let plistStorage = FileSessionStorage(configuration: plistConfig)
        
        plistStorage.save(session: session) { result in
            switch result {
            case .success():
                break // 成功
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            }
            
            plistStorage.load(sessionID: session.id) { loadResult in
                switch loadResult {
                case .success(let loadedSession):
                    XCTAssertNotNil(loadedSession)
                    XCTAssertEqual(loadedSession?.id, session.id)
                    plistExpectation.fulfill()
                case .failure(let error):
                    XCTFail("Plist format failed: \(error)")
                }
            }
        }
        
        wait(for: [jsonExpectation, plistExpectation], timeout: 5.0)
    }
}