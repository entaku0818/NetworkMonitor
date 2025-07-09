import Foundation

// MARK: - Usage Examples
//
// This file contains comprehensive usage examples for NetworkMonitor
// demonstrating common patterns and best practices.

/**
 # NetworkMonitor Usage Examples
 
 This file demonstrates various usage patterns for NetworkMonitor,
 from basic monitoring to advanced filtering and searching capabilities.
 */

// MARK: - Basic Usage Examples

public enum BasicUsageExamples {
    
    /// Example 1: Basic monitoring setup
    public static func basicMonitoringSetup() {
        // Start monitoring
        let result = NetworkMonitorAPI.quickStart()
        
        switch result {
        case .success():
            print("✅ Monitoring started successfully")
            
            // Check monitoring status
            if NetworkMonitorAPI.isMonitoring {
                print("📊 Monitoring is active")
            }
            
        case .failure(let error):
            print("❌ Failed to start monitoring: \(error.localizedDescription)")
        }
    }
    
    /// Example 2: Basic storage operations
    public static func basicStorageOperations() {
        let storage = NetworkMonitorAPI.defaultStorage
        
        // Create a sample session
        let request = HTTPRequest(
            url: "https://api.example.com/users",
            method: .get,
            headers: ["Authorization": "Bearer token"]
        )
        
        let response = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: "{\"users\": []}".data(using: .utf8),
            duration: 0.45
        )
        
        let session = HTTPSession(request: request, response: response, state: .completed)
        
        // Save session
        storage.save(session: session) { result in
            switch result {
            case .success():
                print("✅ Session saved successfully")
                
                // Load it back
                storage.load(sessionID: session.id) { loadResult in
                    switch loadResult {
                    case .success(let loadedSession):
                        print("📖 Loaded session: \(loadedSession?.url ?? "nil")")
                    case .failure(let error):
                        print("❌ Failed to load session: \(error)")
                    }
                }
                
            case .failure(let error):
                print("❌ Failed to save session: \(error)")
            }
        }
    }
    
    /// Example 3: Basic filtering
    public static func basicFiltering() {
        let storage = NetworkMonitorAPI.defaultStorage
        
        // Create filter for successful API calls
        let apiFilter = FilterCriteria()
            .host(pattern: "api.example.com")
            .statusCategory(.success)
        
        // Apply filter
        storage.load(matching: apiFilter) { result in
            switch result {
            case .success(let sessions):
                print("📊 Found \(sessions.count) successful API calls")
            case .failure(let error):
                print("❌ Filtering failed: \(error)")
            }
        }
    }
}

// MARK: - Advanced Usage Examples

public enum AdvancedUsageExamples {
    
    /// Example 1: Complex filtering with multiple conditions
    public static func complexFiltering() {
        let storage = NetworkMonitorAPI.defaultStorage
        
        // Complex filter: JSON API calls that took longer than 500ms
        let complexFilter = FilterCriteria()
            .contentType(NetworkMonitorConstants.ContentTypes.json)
            .duration(min: 0.5, max: 10.0) // Set a reasonable max value
            .statusCategory(.success)
            .host(pattern: "api\\.", isRegex: true) // Regex pattern for API hosts
        
        storage.load(matching: complexFilter) { result in
            switch result {
            case .success(let sessions):
                print("🔍 Found \(sessions.count) slow successful JSON API calls")
                
                // Analyze the results
                let avgDuration = sessions.compactMap { $0.response?.duration }.reduce(0, +) / Double(sessions.count)
                print("📊 Average duration: \(String(format: "%.2f", avgDuration))s")
                
            case .failure(let error):
                print("❌ Complex filtering failed: \(error)")
            }
        }
    }
    
    /// Example 2: Advanced search with highlighting
    public static func advancedSearch() {
        let storage = NetworkMonitorAPI.defaultStorage
        
        // Load all sessions first
        storage.loadAll { result in
            switch result {
            case .success(let sessions):
                
                // Configure search service
                let searchConfig = SessionSearchService.SearchConfiguration(
                    caseSensitive: false,
                    useRegex: true,
                    searchFields: [.url, .host, .requestHeaders, .responseHeaders],
                    enableHighlights: true
                )
                
                let searchService = SessionSearchService(configuration: searchConfig)
                
                // Create complex search query
                let statusFilter = FilterCriteria().statusCodeRange(400..<500) // Client errors
                let searchQuery = SearchQuery(
                    text: "user.*not.*found", // Regex pattern
                    filters: [statusFilter],
                    sortBy: .timestamp,
                    ascending: false
                )
                
                // Perform search
                searchService.search(query: searchQuery, in: sessions) { searchResult in
                    switch searchResult {
                    case .success(let result):
                        print("🔍 Search completed in \(String(format: "%.3f", result.searchTime))s")
                        print("📊 Found \(result.matchCount) matches out of \(result.totalCount) total sessions")
                        
                        // Process highlights
                        for (sessionId, highlights) in result.highlights {
                            print("💡 Session \(sessionId) highlights:")
                            for highlight in highlights {
                                print("   - \(highlight.field.displayName): '\(highlight.matchedText)'")
                            }
                        }
                        
                    case .failure(let error):
                        print("❌ Search failed: \(error)")
                    }
                }
                
            case .failure(let error):
                print("❌ Failed to load sessions: \(error)")
            }
        }
    }
    
    /// Example 3: Storage management and optimization
    public static func storageManagement() {
        let memoryStorage = NetworkMonitorAPI.defaultStorage
        let fileStorage = NetworkMonitorAPI.defaultFileStorage
        
        // Check memory statistics
        let stats = memoryStorage.getMemoryStatistics()
        print("📊 Memory Storage Statistics:")
        print("   - Sessions: \(stats.sessionCount)/\(stats.maxSessions)")
        print("   - Memory usage: \(stats.humanReadableMemoryUsage)")
        print("   - Usage ratio: \(String(format: "%.1f", stats.sessionCountRatio * 100))%")
        
        // If memory usage is high, export to file storage
        if stats.sessionCountRatio > 0.8 {
            print("⚠️  Memory usage is high, exporting to file storage...")
            
            memoryStorage.export(to: fileStorage) { result in
                switch result {
                case .success():
                    print("✅ Export completed successfully")
                    
                    // Clear memory storage to free up space
                    memoryStorage.deleteAll { deleteResult in
                        switch deleteResult {
                        case .success():
                            print("🧹 Memory storage cleared")
                        case .failure(let error):
                            print("❌ Failed to clear memory storage: \(error)")
                        }
                    }
                    
                case .failure(let error):
                    print("❌ Export failed: \(error)")
                }
            }
        }
    }
    
    /// Example 4: Filter engine with analytics
    public static func filterEngineAnalytics() {
        let storage = NetworkMonitorAPI.defaultStorage
        let filterEngine = NetworkMonitorAPI.defaultFilterEngine
        
        storage.loadAll { result in
            switch result {
            case .success(let sessions):
                
                // Define multiple filters for analysis
                let filters = [
                    ("Successful Requests", FilterCriteria().statusCategory(.success)),
                    ("Client Errors", FilterCriteria().statusCategory(.clientError)),
                    ("Server Errors", FilterCriteria().statusCategory(.serverError)),
                    ("Slow Requests", FilterCriteria().duration(min: 1.0, max: nil)),
                    ("API Calls", FilterCriteria().host(pattern: "api\\.", isRegex: true)),
                    ("JSON Responses", FilterCriteria().contentType(NetworkMonitorConstants.ContentTypes.json))
                ]
                
                // Apply each filter and generate statistics
                for (name, criteria) in filters {
                    let filteredSessions = filterEngine.filter(sessions: sessions, using: criteria)
                    let stats = filterEngine.generateSummaryStatistics(for: filteredSessions)
                    
                    print("📊 \(name):")
                    print("   - Count: \(stats["total"] as? Int ?? 0)")
                    print("   - Avg Duration: \(String(format: "%.2f", stats["averageDuration"] as? Double ?? 0.0))s")
                    print("   - Completed: \(stats["completed"] as? Int ?? 0)")
                    print("   - Failed: \(stats["failed"] as? Int ?? 0)")
                    
                    if let hostCounts = stats["hosts"] as? [String: Int], !hostCounts.isEmpty {
                        let topHost = hostCounts.max(by: { $0.value < $1.value })
                        print("   - Top Host: \(topHost?.key ?? "none") (\(topHost?.value ?? 0) requests)")
                    }
                }
                
                // Get overall performance metrics
                if let lastStats = filterEngine.lastFilteringStats {
                    print("\n⚡ Filter Engine Performance:")
                    print("   - Last Processing Time: \(String(format: "%.3f", lastStats.processingTime))s")
                    print("   - Filtering Ratio: \(String(format: "%.1f", lastStats.filteringRatio * 100))%")
                }
                
            case .failure(let error):
                print("❌ Failed to load sessions: \(error)")
            }
        }
    }
}

// MARK: - Integration Examples

public enum IntegrationExamples {
    
    /// Example 1: Custom storage implementation
    public static func customStorageImplementation() {
        // This example shows how to create a custom storage implementation
        
        class CustomCloudStorage: SessionStorageProtocol {
            
            func save(session: HTTPSession, completion: @escaping (Result<Void, Error>) -> Void) {
                // Implement cloud storage save logic
                DispatchQueue.global().async {
                    // Simulate async operation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        completion(.success(()))
                    }
                }
            }
            
            func save(sessions: [HTTPSession], completion: @escaping (Result<Void, Error>) -> Void) {
                // Implement bulk save
                DispatchQueue.global().async {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        completion(.success(()))
                    }
                }
            }
            
            func load(sessionID: UUID, completion: @escaping (Result<HTTPSession?, Error>) -> Void) {
                // Implement load by ID
                completion(.success(nil))
            }
            
            func loadAll(completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
                // Implement load all
                completion(.success([]))
            }
            
            func load(matching criteria: FilterCriteriaProtocol, completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
                // Implement filtered load
                completion(.success([]))
            }
            
            func delete(sessionID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
                // Implement delete
                completion(.success(()))
            }
            
            func deleteAll(completion: @escaping (Result<Void, Error>) -> Void) {
                // Implement delete all
                completion(.success(()))
            }
            
            func delete(matching criteria: FilterCriteriaProtocol, completion: @escaping (Result<Int, Error>) -> Void) {
                // Implement filtered delete
                completion(.success(0))
            }
            
            func count(completion: @escaping (Result<Int, Error>) -> Void) {
                // Implement count
                completion(.success(0))
            }
            
            func storageSize(completion: @escaping (Result<Int64, Error>) -> Void) {
                // Implement size calculation
                completion(.success(0))
            }
        }
        
        // Usage
        let _ = CustomCloudStorage()
        print("☁️  Custom cloud storage implementation ready")
    }
    
    /// Example 2: Custom filter criteria
    public static func customFilterCriteria() {
        // Create a custom filter that matches sessions with specific patterns
        
        struct CustomBusinessLogicFilter: FilterCriteriaProtocol {
            let minRequestsPerHost: Int
            
            func matches(session: HTTPSession) -> Bool {
                // Implement custom business logic
                // This is a simplified example - in practice you might need
                // access to all sessions to count requests per host
                
                guard let url = URL(string: session.request.url) else { return false }
                guard let host = url.host else { return false }
                
                // Custom logic: filter based on host patterns
                let businessApiHosts = ["api.business.com", "internal.company.com"]
                return businessApiHosts.contains(host)
            }
        }
        
        // Usage
        let _ = CustomBusinessLogicFilter(minRequestsPerHost: 5)
        print("🔧 Custom filter criteria implementation ready")
    }
    
    /// Example 3: Real-time monitoring with observers
    public static func realTimeMonitoringSetup() {
        // This example shows how to set up real-time monitoring
        // (Note: Actual network interception would be implemented in future issues)
        
        class NetworkSessionObserver {
            private let storage: SessionStorageProtocol
            private let filterEngine: FilterEngine
            
            init(storage: SessionStorageProtocol) {
                self.storage = storage
                self.filterEngine = FilterEngine()
            }
            
            func sessionCompleted(_ session: HTTPSession) {
                // Save the session
                storage.save(session: session) { result in
                    switch result {
                    case .success():
                        print("📝 Session saved: \(session.url)")
                        
                        // Apply real-time filtering for alerts
                        self.checkForAlerts(session)
                        
                    case .failure(let error):
                        print("❌ Failed to save session: \(error)")
                    }
                }
            }
            
            private func checkForAlerts(_ session: HTTPSession) {
                // Check for error conditions
                let errorFilter = FilterCriteria().statusCategory(.serverError)
                if errorFilter.matches(session: session) {
                    print("🚨 Server error detected: \(session.statusCode ?? 0) on \(session.url)")
                }
                
                // Check for slow requests
                let slowFilter = FilterCriteria().duration(min: 3.0, max: nil)
                if slowFilter.matches(session: session) {
                    let duration = session.response?.duration ?? 0
                    print("🐌 Slow request detected: \(String(format: "%.2f", duration))s on \(session.url)")
                }
            }
        }
        
        // Setup observer
        let _ = NetworkSessionObserver(storage: NetworkMonitorAPI.defaultStorage)
        print("👀 Real-time monitoring observer setup complete")
    }
}