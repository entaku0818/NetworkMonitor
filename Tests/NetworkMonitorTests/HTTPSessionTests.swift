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
        let relatedIDs = [UUID(), UUID()]
        let parentID = UUID()
        
        // Act
        let session = HTTPSession(
            id: id,
            request: request,
            state: .initialized,
            startTime: startTime,
            relatedSessionIDs: relatedIDs,
            parentSessionID: parentID
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
        XCTAssertEqual(session.relatedSessionIDs, relatedIDs)
        XCTAssertEqual(session.parentSessionID, parentID)
        XCTAssertTrue(session.hasParent)
        XCTAssertTrue(session.hasChildren)
    }
    
    func testLegacyMetadataInitialization() {
        // Arrange
        let legacyMetadata = ["key1": "value1", "key2": "value2"]
        
        // Act
        let session = HTTPSession(
            request: createTestRequest(),
            legacyMetadata: legacyMetadata
        )
        
        // Assert
        XCTAssertEqual(session.metadata.count, 2)
        if case let .string(value) = session.metadata["key1"] {
            XCTAssertEqual(value, "value1")
        } else {
            XCTFail("Expected string metadata value")
        }
        
        if case let .string(value) = session.metadata["key2"] {
            XCTAssertEqual(value, "value2")
        } else {
            XCTFail("Expected string metadata value")
        }
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
    
    func testEnhancedMetadataManagement() {
        // Arrange
        let session = HTTPSession(request: createTestRequest())
        let now = Date()
        
        // Act - add different types of metadata
        let withStringMetadata = session.addMetadata(key: "string_key", value: "string_value")
        let withIntMetadata = withStringMetadata.addMetadata(key: "int_key", value: 42)
        let withDoubleMetadata = withIntMetadata.addMetadata(key: "double_key", value: 3.14)
        let withBoolMetadata = withDoubleMetadata.addMetadata(key: "bool_key", value: true)
        let withDateMetadata = withBoolMetadata.addMetadata(key: "date_key", value: now)
        
        // Assert
        XCTAssertEqual(withDateMetadata.metadata.count, 5)
        
        if case let .string(value) = withDateMetadata.metadata["string_key"] {
            XCTAssertEqual(value, "string_value")
        } else {
            XCTFail("Expected string metadata value")
        }
        
        if case let .int(value) = withDateMetadata.metadata["int_key"] {
            XCTAssertEqual(value, 42)
        } else {
            XCTFail("Expected int metadata value")
        }
        
        if case let .double(value) = withDateMetadata.metadata["double_key"] {
            XCTAssertEqual(value, 3.14)
        } else {
            XCTFail("Expected double metadata value")
        }
        
        if case let .bool(value) = withDateMetadata.metadata["bool_key"] {
            XCTAssertTrue(value)
        } else {
            XCTFail("Expected bool metadata value")
        }
        
        if case let .date(value) = withDateMetadata.metadata["date_key"] {
            XCTAssertEqual(value, now)
        } else {
            XCTFail("Expected date metadata value")
        }
        
        // Act - batch add metadata
        let batchMetadata: [String: HTTPSession.MetadataValue] = [
            "batch_key1": .string("batch_value1"),
            "batch_key2": .int(100)
        ]
        let withBatchMetadata = withDateMetadata.addMetadata(batchMetadata)
        
        // Assert
        XCTAssertEqual(withBatchMetadata.metadata.count, 7)
        
        if case let .string(value) = withBatchMetadata.metadata["batch_key1"] {
            XCTAssertEqual(value, "batch_value1")
        } else {
            XCTFail("Expected string metadata value")
        }
        
        // Act - remove metadata
        let withRemovedMetadata = withBatchMetadata.removeMetadata(key: "batch_key1")
        
        // Assert
        XCTAssertEqual(withRemovedMetadata.metadata.count, 6)
        XCTAssertNil(withRemovedMetadata.metadata["batch_key1"])
    }
    
    func testMetadataStringValue() {
        // Arrange
        let now = Date()
        let stringValue = HTTPSession.MetadataValue.string("test")
        let intValue = HTTPSession.MetadataValue.int(42)
        let doubleValue = HTTPSession.MetadataValue.double(3.14)
        let boolValue = HTTPSession.MetadataValue.bool(true)
        let dateValue = HTTPSession.MetadataValue.date(now)
        
        // Act & Assert
        XCTAssertEqual(stringValue.stringValue, "test")
        XCTAssertEqual(intValue.stringValue, "42")
        XCTAssertEqual(doubleValue.stringValue, "3.14")
        XCTAssertEqual(boolValue.stringValue, "true")
        
        let formatter = ISO8601DateFormatter()
        XCTAssertEqual(dateValue.stringValue, formatter.string(from: now))
    }
    
    func testRelatedSessionManagement() {
        // Arrange
        let session = HTTPSession(request: createTestRequest())
        let relatedID1 = UUID()
        let relatedID2 = UUID()
        
        // Act - add related sessions
        let withOneRelated = session.addRelatedSession(sessionID: relatedID1)
        let withTwoRelated = withOneRelated.addRelatedSession(sessionID: relatedID2)
        
        // Assert
        XCTAssertEqual(withTwoRelated.relatedSessionIDs.count, 2)
        XCTAssertTrue(withTwoRelated.relatedSessionIDs.contains(relatedID1))
        XCTAssertTrue(withTwoRelated.relatedSessionIDs.contains(relatedID2))
        XCTAssertTrue(withTwoRelated.hasChildren)
        
        // Act - add duplicate (should have no effect)
        let withDuplicate = withTwoRelated.addRelatedSession(sessionID: relatedID1)
        
        // Assert
        XCTAssertEqual(withDuplicate.relatedSessionIDs.count, 2)
        
        // Act - remove related session
        let withOneRemoved = withDuplicate.removeRelatedSession(sessionID: relatedID1)
        
        // Assert
        XCTAssertEqual(withOneRemoved.relatedSessionIDs.count, 1)
        XCTAssertFalse(withOneRemoved.relatedSessionIDs.contains(relatedID1))
        XCTAssertTrue(withOneRemoved.relatedSessionIDs.contains(relatedID2))
    }
    
    func testCreateChildSession() {
        // Arrange
        let parentSession = HTTPSession(request: createTestRequest())
        let childRequest = HTTPRequest(url: "https://api.example.com/child", method: .post)
        
        // Act
        let childSession = parentSession.createChildSession(request: childRequest)
        
        // Assert
        XCTAssertEqual(childSession.parentSessionID, parentSession.id)
        XCTAssertEqual(childSession.request, childRequest)
        XCTAssertTrue(childSession.hasParent)
        XCTAssertFalse(childSession.hasChildren)
    }
    
    func testMetadataValueCodable() {
        // Arrange
        let now = Date()
        let originalMetadata: [String: HTTPSession.MetadataValue] = [
            "string": .string("test"),
            "int": .int(42),
            "double": .double(3.14),
            "bool": .bool(true),
            "date": .date(now)
        ]
        
        let session = HTTPSession(
            request: createTestRequest(),
            metadata: originalMetadata
        )
        
        // Act - encode and decode
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(session)
            
            let decoder = JSONDecoder()
            let decodedSession = try decoder.decode(HTTPSession.self, from: data)
            
            // Assert
            XCTAssertEqual(decodedSession.metadata.count, 5)
            
            if case let .string(value) = decodedSession.metadata["string"] {
                XCTAssertEqual(value, "test")
            } else {
                XCTFail("Expected string metadata value")
            }
            
            if case let .int(value) = decodedSession.metadata["int"] {
                XCTAssertEqual(value, 42)
            } else {
                XCTFail("Expected int metadata value")
            }
            
            if case let .double(value) = decodedSession.metadata["double"] {
                XCTAssertEqual(value, 3.14)
            } else {
                XCTFail("Expected double metadata value")
            }
            
            if case let .bool(value) = decodedSession.metadata["bool"] {
                XCTAssertTrue(value)
            } else {
                XCTFail("Expected bool metadata value")
            }
            
            if case let .date(value) = decodedSession.metadata["date"] {
                XCTAssertEqual(value, now)
            } else {
                XCTFail("Expected date metadata value")
            }
            
        } catch {
            XCTFail("Failed to encode/decode HTTPSession metadata: \(error)")
        }
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
        let relatedID = UUID()
        let parentID = UUID()
        
        let session = HTTPSession(
            request: request,
            response: response,
            state: .completed,
            startTime: Date(),
            endTime: Date().addingTimeInterval(1.5),
            metadata: [
                "category": .string("api"),
                "priority": .string("high"),
                "retry_count": .int(3),
                "success_rate": .double(0.75),
                "is_cached": .bool(false)
            ],
            retryCount: 2,
            relatedSessionIDs: [relatedID],
            parentSessionID: parentID
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
        XCTAssertTrue(description.contains("retry_count: 3"))
        XCTAssertTrue(description.contains("success_rate: 0.75"))
        XCTAssertTrue(description.contains("is_cached: false"))
        XCTAssertTrue(description.contains("Retries: 2"))
        XCTAssertTrue(description.contains("Related Sessions: 1"))
        XCTAssertTrue(description.contains("Parent: \(parentID)"))
    }
    
    func testCodable() {
        // Arrange
        let request = createTestRequest()
        let response = createTestResponse()
        let relatedID = UUID()
        let parentID = UUID()
        
        let originalSession = HTTPSession(
            request: request,
            response: response,
            state: .completed,
            startTime: Date(),
            responseStartTime: Date(),
            endTime: Date(),
            requestDuration: 0.3,
            metadata: ["test": .string("value"), "count": .int(42)],
            retryCount: 1,
            relatedSessionIDs: [relatedID],
            parentSessionID: parentID
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
            XCTAssertEqual(decodedSession.retryCount, originalSession.retryCount)
            XCTAssertEqual(decodedSession.relatedSessionIDs, originalSession.relatedSessionIDs)
            XCTAssertEqual(decodedSession.parentSessionID, originalSession.parentSessionID)
            
            if case let .string(value) = decodedSession.metadata["test"] {
                XCTAssertEqual(value, "value")
            } else {
                XCTFail("Failed to decode string metadata")
            }
            
            if case let .int(value) = decodedSession.metadata["count"] {
                XCTAssertEqual(value, 42)
            } else {
                XCTFail("Failed to decode int metadata")
            }
            
        } catch {
            XCTFail("Failed to encode/decode HTTPSession: \(error)")
        }
    }
} 