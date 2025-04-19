import XCTest
@testable import NetworkMonitor

final class HTTPSessionTests: XCTestCase {
    
    // テスト用のリクエストを作成するヘルパーメソッド
    private func createTestRequest() -> HTTPRequest {
        return HTTPRequest(
            url: "https://api.example.com/test",
            method: .get,
            headers: ["Accept": "application/json"]
        )
    }
    
    // テスト用のレスポンスを作成するヘルパーメソッド
    private func createTestResponse(statusCode: Int = 200) -> HTTPResponse {
        return HTTPResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            body: "{\"result\":\"success\"}".data(using: .utf8),
            duration: 0.5
        )
    }
    
    func testInitialization() {
        // Arrange
        let request = createTestRequest()
        let id = UUID()
        let startTime = Date()
        
        // Act
        let session = HTTPSession(
            id: id,
            request: request,
            state: .initialized,
            startTime: startTime
        )
        
        // Assert
        XCTAssertEqual(session.id, id)
        XCTAssertEqual(session.request, request)
        XCTAssertNil(session.response)
        XCTAssertEqual(session.state, .initialized)
        XCTAssertEqual(session.startTime, startTime)
        XCTAssertNil(session.responseStartTime)
        XCTAssertNil(session.endTime)
        XCTAssertNil(session.requestDuration)
        XCTAssertTrue(session.metadata.isEmpty)
        XCTAssertNil(session.queuedTime)
        XCTAssertEqual(session.retryCount, 0)
        XCTAssertFalse(session.usedSSLDecryption)
    }
    
    func testStateTransitions() {
        // Arrange
        let request = createTestRequest()
        let response = createTestResponse()
        let session = HTTPSession(request: request)
        
        // Act & Assert - sending
        let sendingSession = session.sending()
        XCTAssertEqual(sendingSession.state, .sending)
        
        // Act & Assert - waiting
        let waitingSession = sendingSession.waiting(requestDuration: 0.2)
        XCTAssertEqual(waitingSession.state, .waiting)
        XCTAssertEqual(waitingSession.requestDuration, 0.2)
        
        // Act & Assert - receiving
        let receivingTime = Date()
        let receivingSession = waitingSession.receiving(responseStartTime: receivingTime)
        XCTAssertEqual(receivingSession.state, .receiving)
        XCTAssertEqual(receivingSession.responseStartTime, receivingTime)
        
        // Act & Assert - completed
        let completedTime = Date()
        let completedSession = receivingSession.completed(response: response, endTime: completedTime)
        XCTAssertEqual(completedSession.state, .completed)
        XCTAssertEqual(completedSession.response, response)
        XCTAssertEqual(completedSession.endTime, completedTime)
        
        // Act & Assert - failed
        let error = NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let failedTime = Date()
        let failedSession = session.failed(error: error, endTime: failedTime)
        XCTAssertEqual(failedSession.state, .failed)
        XCTAssertEqual(failedSession.endTime, failedTime)
        XCTAssertEqual(failedSession.response?.error?.localizedDescription, error.localizedDescription)
        
        // Act & Assert - cancelled
        let cancelledTime = Date()
        let cancelledSession = session.cancelled(endTime: cancelledTime)
        XCTAssertEqual(cancelledSession.state, .cancelled)
        XCTAssertEqual(cancelledSession.endTime, cancelledTime)
    }
    
    func testRetryIncrement() {
        // Arrange
        let session = HTTPSession(request: createTestRequest())
        
        // Act
        let retriedSession = session.incrementRetry().incrementRetry()
        
        // Assert
        XCTAssertEqual(retriedSession.retryCount, 2)
    }
    
    func testMetadataManagement() {
        // Arrange
        let session = HTTPSession(request: createTestRequest())
        
        // Act - add single metadata
        let withMetadata = session.addMetadata(key: "test_key", value: "test_value")
        
        // Assert
        XCTAssertEqual(withMetadata.metadata["test_key"], "test_value")
        
        // Act - add multiple metadata
        let additionalMetadata: [String: String] = ["key1": "value1", "key2": "value2"]
        let withMoreMetadata = withMetadata.addMetadata(additionalMetadata)
        
        // Assert
        XCTAssertEqual(withMoreMetadata.metadata.count, 3)
        XCTAssertEqual(withMoreMetadata.metadata["key1"], "value1")
        XCTAssertEqual(withMoreMetadata.metadata["key2"], "value2")
        
        // Act - remove metadata
        let withRemovedMetadata = withMoreMetadata.removeMetadata(key: "key1")
        
        // Assert
        XCTAssertEqual(withRemovedMetadata.metadata.count, 2)
        XCTAssertNil(withRemovedMetadata.metadata["key1"])
        XCTAssertEqual(withRemovedMetadata.metadata["key2"], "value2")
    }
    
    func testAccessorProperties() {
        // Arrange
        let request = HTTPRequest(
            url: "https://api.example.com/path/to/resource",
            method: .post,
            headers: ["Content-Type": "application/json"]
        )
        let response = HTTPResponse(statusCode: 201)
        let session = HTTPSession(request: request, response: response, state: .completed)
        
        // Assert
        XCTAssertEqual(session.httpMethod, "POST")
        XCTAssertEqual(session.url, "https://api.example.com/path/to/resource")
        XCTAssertEqual(session.host, "api.example.com")
        XCTAssertEqual(session.path, "/path/to/resource")
        XCTAssertEqual(session.statusCode, 201)
    }
    
    func testStateCheckProperties() {
        // Test completed
        let completed = HTTPSession(
            request: createTestRequest(),
            response: createTestResponse(),
            state: .completed
        )
        XCTAssertTrue(completed.isCompleted)
        XCTAssertFalse(completed.isFailed)
        XCTAssertFalse(completed.isCancelled)
        XCTAssertTrue(completed.isFinished)
        XCTAssertFalse(completed.isOngoing)
        
        // Test failed
        let failed = HTTPSession(
            request: createTestRequest(),
            state: .failed
        )
        XCTAssertFalse(failed.isCompleted)
        XCTAssertTrue(failed.isFailed)
        XCTAssertFalse(failed.isCancelled)
        XCTAssertTrue(failed.isFinished)
        XCTAssertFalse(failed.isOngoing)
        
        // Test cancelled
        let cancelled = HTTPSession(
            request: createTestRequest(),
            state: .cancelled
        )
        XCTAssertFalse(cancelled.isCompleted)
        XCTAssertFalse(cancelled.isFailed)
        XCTAssertTrue(cancelled.isCancelled)
        XCTAssertTrue(cancelled.isFinished)
        XCTAssertFalse(cancelled.isOngoing)
        
        // Test ongoing
        let ongoing = HTTPSession(
            request: createTestRequest(),
            state: .waiting
        )
        XCTAssertFalse(ongoing.isCompleted)
        XCTAssertFalse(ongoing.isFailed)
        XCTAssertFalse(ongoing.isCancelled)
        XCTAssertFalse(ongoing.isFinished)
        XCTAssertTrue(ongoing.isOngoing)
    }
    
    func testDurationCalculation() {
        // Arrange
        let now = Date()
        let startTime = now.addingTimeInterval(-10) // 10 seconds ago
        let responseStartTime = now.addingTimeInterval(-5) // 5 seconds ago
        let endTime = now.addingTimeInterval(-2) // 2 seconds ago
        
        // Act & Assert - completed session
        let completedSession = HTTPSession(
            request: createTestRequest(),
            response: HTTPResponse(statusCode: 200, duration: 1.0),
            state: .completed,
            startTime: startTime,
            responseStartTime: responseStartTime,
            endTime: endTime
        )
        // Duration should be from start to end (10 - 2 = 8 seconds)
        XCTAssertEqual(completedSession.duration, 8.0, accuracy: 0.1)
        
        // Act & Assert - ongoing session (receiving)
        let receivingSession = HTTPSession(
            request: createTestRequest(),
            response: HTTPResponse(statusCode: 200, duration: 1.0),
            state: .receiving,
            startTime: startTime,
            responseStartTime: responseStartTime
        )
        // Receiving duration is more complex and time-dependent, so we just check it's reasonable
        XCTAssertGreaterThan(receivingSession.duration, 4.9) // At least time since responseStartTime
        
        // Act & Assert - ongoing session (waiting)
        let waitingSession = HTTPSession(
            request: createTestRequest(),
            state: .waiting,
            startTime: startTime
        )
        // Waiting duration should be from start to now (approximately 10 seconds)
        XCTAssertGreaterThan(waitingSession.duration, 9.9)
    }
    
    func testEquatableAndHashable() {
        // Arrange
        let id1 = UUID()
        let id2 = UUID()
        
        let session1a = HTTPSession(
            id: id1,
            request: createTestRequest()
        )
        
        let session1b = HTTPSession(
            id: id1,
            request: createTestRequest(),
            response: createTestResponse(),
            state: .completed
        )
        
        let session2 = HTTPSession(
            id: id2,
            request: createTestRequest()
        )
        
        // Assert Equatable
        XCTAssertEqual(session1a, session1b) // Same ID, different state
        XCTAssertNotEqual(session1a, session2) // Different ID
        
        // Assert Hashable
        var hashSet = Set<HTTPSession>()
        hashSet.insert(session1a)
        hashSet.insert(session1b)
        hashSet.insert(session2)
        
        XCTAssertEqual(hashSet.count, 2) // Only 2 unique sessions by ID
    }
    
    func testDescription() {
        // Arrange
        let request = createTestRequest()
        let response = createTestResponse(statusCode: 404)
        let session = HTTPSession(
            request: request,
            response: response,
            state: .completed,
            startTime: Date(),
            endTime: Date().addingTimeInterval(1.5),
            metadata: ["category": "api", "priority": "high"],
            retryCount: 2
        )
        
        // Act
        let description = session.description
        
        // Assert
        XCTAssertTrue(description.contains("[GET]"))
        XCTAssertTrue(description.contains("https://api.example.com/test"))
        XCTAssertTrue(description.contains("State: completed"))
        XCTAssertTrue(description.contains("Status: 404"))
        XCTAssertTrue(description.contains("Duration:"))
        XCTAssertTrue(description.contains("category: api"))
        XCTAssertTrue(description.contains("priority: high"))
        XCTAssertTrue(description.contains("Retries: 2"))
    }
    
    func testCodable() {
        // Arrange
        let request = createTestRequest()
        let response = createTestResponse()
        let originalSession = HTTPSession(
            request: request,
            response: response,
            state: .completed,
            startTime: Date(),
            responseStartTime: Date(),
            endTime: Date(),
            requestDuration: 0.3,
            metadata: ["test": "value"],
            retryCount: 1
        )
        
        // Act - Encode and decode
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(originalSession)
            
            let decoder = JSONDecoder()
            let decodedSession = try decoder.decode(HTTPSession.self, from: data)
            
            // Assert
            XCTAssertEqual(decodedSession.id, originalSession.id)
            XCTAssertEqual(decodedSession.request.url, originalSession.request.url)
            XCTAssertEqual(decodedSession.request.method, originalSession.request.method)
            XCTAssertEqual(decodedSession.response?.statusCode, originalSession.response?.statusCode)
            XCTAssertEqual(decodedSession.state, originalSession.state)
            XCTAssertEqual(decodedSession.requestDuration, originalSession.requestDuration)
            XCTAssertEqual(decodedSession.metadata, originalSession.metadata)
            XCTAssertEqual(decodedSession.retryCount, originalSession.retryCount)
        } catch {
            XCTFail("Failed to encode/decode HTTPSession: \(error)")
        }
    }
} 