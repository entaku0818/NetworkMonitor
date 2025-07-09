import Foundation

// MARK: - Public API Overview
//
// This file provides a comprehensive overview of NetworkMonitor's public API
// and serves as a reference for the main use cases and interfaces.

/**
 # NetworkMonitor Public API Overview
 
 NetworkMonitor provides a comprehensive suite of tools for monitoring, analyzing,
 and filtering network traffic in iOS, macOS, watchOS, and tvOS applications.
 
 ## Core Components
 
 ### 1. NetworkMonitor (Main Interface)
 - Singleton pattern for global network monitoring
 - Built-in security features for release builds
 - Simple start/stop controls
 
 ### 2. Models
 - `HTTPRequest`: Represents HTTP request data
 - `HTTPResponse`: Represents HTTP response data  
 - `HTTPSession`: Complete request/response lifecycle with metadata
 
 ### 3. Storage System
 - `SessionStorageProtocol`: Abstract storage interface
 - `FileSessionStorage`: Persistent file-based storage
 - `InMemorySessionStorage`: High-performance memory storage
 
 ### 4. Filtering System
 - `FilterCriteria`: Fluent API for building complex filters
 - `FilterEngine`: High-performance filtering and analysis
 
 ### 5. Search System
 - `SessionSearchService`: Full-text search with highlighting
 - Advanced query capabilities with sorting and pagination
 
 ## Basic Usage Examples
 
 ```swift
 // Start monitoring
 NetworkMonitor.shared.start()
 
 // Create storage
 let storage = InMemorySessionStorage()
 
 // Filter sessions
 let criteria = FilterCriteria()
     .host(pattern: "api.example.com")
     .method(.GET)
     .statusCategory(.success)
 
 storage.load(matching: criteria) { result in
     switch result {
     case .success(let sessions):
         print("Found \(sessions.count) matching sessions")
     case .failure(let error):
         print("Error: \(error)")
     }
 }
 
 // Search sessions
 let searchService = SessionSearchService()
 let query = SearchQuery(text: "github", sortBy: .timestamp)
 
 searchService.search(query: query, in: sessions) { result in
     switch result {
     case .success(let searchResult):
         print("Found \(searchResult.matchCount) matches")
         print("Search took \(searchResult.searchTime)s")
     case .failure(let error):
         print("Search error: \(error)")
     }
 }
 ```
 
 ## Advanced Usage
 
 ### Complex Filtering
 ```swift
 let complexFilter = FilterCriteria()
     .host(pattern: "api.*", isRegex: true)
     .statusCodeRange(200..<300)
     .duration(min: 0.5, max: nil)
     .and()
     .contentType("application/json")
 ```
 
 ### Storage Operations
 ```swift
 // Export sessions
 let fileStorage = FileSessionStorage()
 memoryStorage.export(to: fileStorage) { result in
     // Handle export result
 }
 
 // Get storage statistics
 let stats = memoryStorage.getMemoryStatistics()
 print("Memory usage: \(stats.humanReadableMemoryUsage)")
 ```
 
 ### Search Configuration
 ```swift
 let searchConfig = SessionSearchService.SearchConfiguration(
     caseSensitive: false,
     useRegex: true,
     searchFields: [.url, .host, .requestHeaders]
 )
 let searchService = SessionSearchService(configuration: searchConfig)
 ```
 */

// MARK: - Public API Facade

/// Convenience facade for common NetworkMonitor operations
public final class NetworkMonitorAPI {
    
    /// Quick access to the main NetworkMonitor instance
    public static var monitor: NetworkMonitor { NetworkMonitor.shared }
    
    /// Default in-memory storage instance
    public static let defaultStorage = InMemorySessionStorage()
    
    /// Default file storage instance
    public static let defaultFileStorage = FileSessionStorage()
    
    /// Default search service instance
    public static let defaultSearchService = SessionSearchService()
    
    /// Default filter engine instance
    public static let defaultFilterEngine = FilterEngine()
    
    // MARK: - Quick Actions
    
    /// Quick start monitoring with default settings
    /// - Returns: Success or failure result
    public static func quickStart() -> Result<Void, NetworkMonitorError> {
        return monitor.performSafetyCheck().flatMap { _ in
            monitor.start()
            return monitor.isActive() ? .success(()) : .failure(.startupFailed)
        }
    }
    
    /// Quick stop monitoring
    public static func quickStop() {
        monitor.stop()
    }
    
    /// Get current monitoring status
    public static var isMonitoring: Bool {
        monitor.isActive()
    }
    
    /// Get monitoring state
    public static var monitoringState: NetworkMonitor.MonitoringState {
        monitor.monitoringState()
    }
    
    // MARK: - Quick Filtering
    
    /// Quick filter by host
    /// - Parameter host: Host to filter by
    /// - Returns: Filter criteria for host
    public static func filterByHost(_ host: String) -> FilterCriteria {
        return FilterCriteria().host(pattern: host)
    }
    
    /// Quick filter by method
    /// - Parameter method: HTTP method to filter by
    /// - Returns: Filter criteria for method
    public static func filterByMethod(_ method: HTTPRequest.Method) -> FilterCriteria {
        return FilterCriteria().method(method)
    }
    
    /// Quick filter by status code
    /// - Parameter statusCode: Status code to filter by
    /// - Returns: Filter criteria for status code
    public static func filterByStatusCode(_ statusCode: Int) -> FilterCriteria {
        return FilterCriteria().statusCode(statusCode)
    }
    
    /// Quick filter for successful requests only
    /// - Returns: Filter criteria for successful requests
    public static func successfulRequestsOnly() -> FilterCriteria {
        return FilterCriteria().statusCategory(.success)
    }
    
    /// Quick filter for error requests only
    /// - Returns: Filter criteria for error requests
    public static func errorRequestsOnly() -> FilterCriteria {
        return FilterCriteria().statusCategory(.clientError, logicalOperator: .or).statusCategory(.serverError)
    }
    
    // MARK: - Quick Search
    
    /// Quick text search in sessions
    /// - Parameters:
    ///   - text: Text to search for
    ///   - sessions: Sessions to search in
    ///   - completion: Completion handler with search results
    public static func quickSearch(text: String, in sessions: [HTTPSession], completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
        defaultSearchService.simpleSearch(text: text, in: sessions, completion: completion)
    }
    
    /// Quick search by host
    /// - Parameters:
    ///   - host: Host to search for
    ///   - sessions: Sessions to search in
    ///   - completion: Completion handler with search results
    public static func quickSearchByHost(_ host: String, in sessions: [HTTPSession], completion: @escaping (Result<SessionSearchService.SearchResult, Error>) -> Void) {
        defaultSearchService.searchByHost(host, in: sessions, completion: completion)
    }
    
    // MARK: - Quick Storage Operations
    
    /// Get session count from default storage
    /// - Parameter completion: Completion handler with count
    public static func getSessionCount(completion: @escaping (Result<Int, Error>) -> Void) {
        defaultStorage.count(completion: completion)
    }
    
    /// Get storage size from default storage
    /// - Parameter completion: Completion handler with size in bytes
    public static func getStorageSize(completion: @escaping (Result<Int64, Error>) -> Void) {
        defaultStorage.storageSize(completion: completion)
    }
    
    /// Get memory statistics from default storage
    /// - Returns: Memory statistics
    public static func getMemoryStatistics() -> MemoryStatistics {
        return defaultStorage.getMemoryStatistics()
    }
    
    /// Clear all sessions from default storage
    /// - Parameter completion: Completion handler
    public static func clearAllSessions(completion: @escaping (Result<Void, Error>) -> Void) {
        defaultStorage.deleteAll(completion: completion)
    }
}

// MARK: - Public API Constants

/// Public constants for NetworkMonitor
public enum NetworkMonitorConstants {
    /// Current version of the library
    public static let version = NetworkMonitor.version
    
    /// Build information
    public static let buildInfo = NetworkMonitor.buildInfo
    
    /// Default storage limits
    public enum StorageLimits {
        public static let defaultMaxSessions = 1000
        public static let defaultMaxMemoryUsage: Int64 = 100 * 1024 * 1024 // 100MB
        public static let defaultRetentionPeriod: TimeInterval = 60 * 60 // 1 hour
    }
    
    /// Default search limits
    public enum SearchLimits {
        public static let defaultMaxResults = 1000
        public static let defaultTimeout: TimeInterval = 10.0
    }
    
    /// Common MIME types for filtering
    public enum ContentTypes {
        public static let json = "application/json"
        public static let xml = "application/xml"
        public static let html = "text/html"
        public static let plainText = "text/plain"
        public static let formData = "application/x-www-form-urlencoded"
        public static let multipartFormData = "multipart/form-data"
    }
    
    /// Common hosts for filtering
    public enum CommonHosts {
        public static let localhost = "localhost"
        public static let github = "github.com"
        public static let google = "google.com"
        public static let apple = "apple.com"
    }
}

// MARK: - Public API Validation

/// Validates the public API design and usage patterns
public enum NetworkMonitorAPIValidator {
    
    /// Validates a storage configuration
    /// - Parameter config: Storage configuration to validate
    /// - Returns: Validation result
    public static func validateStorageConfiguration<T: SessionStorageProtocol>(_ storage: T) -> Bool {
        // Basic validation - can extend as needed
        return true
    }
    
    /// Validates a filter criteria
    /// - Parameter criteria: Filter criteria to validate
    /// - Returns: Validation result
    public static func validateFilterCriteria(_ criteria: FilterCriteriaProtocol) -> Bool {
        // Test with a dummy session to ensure criteria doesn't crash
        let testRequest = HTTPRequest(url: "https://example.com", method: .get)
        let testResponse = HTTPResponse(statusCode: 200, duration: 0.1)
        let testSession = HTTPSession(request: testRequest, response: testResponse, state: .completed)
        
        _ = criteria.matches(session: testSession)
        return true
    }
    
    /// Validates a search query
    /// - Parameter query: Search query to validate
    /// - Returns: Validation result
    public static func validateSearchQuery(_ query: SearchQuery) -> Bool {
        // Basic validation
        if query.text.isEmpty && query.filters == nil && query.dateRange == nil {
            return false // At least one criteria should be specified
        }
        return true
    }
}