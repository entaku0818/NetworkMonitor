import Foundation
import NetworkMonitor

/**
 # NetworkMonitor Basic Usage Examples
 
 This file demonstrates basic usage patterns for NetworkMonitor.
 Copy and modify these examples for your own projects.
 */

// MARK: - Basic Setup Example

/// Example 1: Getting started with NetworkMonitor
func example1_GettingStarted() {
    print("=== Example 1: Getting Started ===")
    
    // Start monitoring network traffic
    let result = NetworkMonitorAPI.quickStart()
    
    switch result {
    case .success():
        print("✅ Network monitoring started successfully")
        
        // Check if monitoring is active
        if NetworkMonitorAPI.isMonitoring {
            print("📊 Monitoring is currently active")
            print("📱 State: \(NetworkMonitorAPI.monitoringState)")
        }
        
        // Stop monitoring when done
        NetworkMonitorAPI.quickStop()
        print("🛑 Monitoring stopped")
        
    case .failure(let error):
        print("❌ Failed to start monitoring: \(error.localizedDescription)")
    }
}

// MARK: - Storage Examples

/// Example 2: Working with session storage
func example2_BasicStorage() {
    print("\n=== Example 2: Basic Storage ===")
    
    // Get default storage instance
    let storage = NetworkMonitorAPI.defaultStorage
    
    // Create a sample HTTP session
    let request = HTTPRequest(
        url: "https://api.example.com/users",
        method: .get,
        headers: [
            "Authorization": "Bearer your-token-here",
            "Content-Type": "application/json"
        ]
    )
    
    let response = HTTPResponse(
        statusCode: 200,
        headers: ["Content-Type": "application/json"],
        body: "{\"users\": [{\"id\": 1, \"name\": \"John\"}]}".data(using: .utf8),
        duration: 0.35
    )
    
    let session = HTTPSession(
        request: request,
        response: response,
        state: .completed
    )
    
    // Save the session
    storage.save(session: session) { result in
        switch result {
        case .success():
            print("✅ Session saved successfully")
            
            // Load it back to verify
            storage.load(sessionID: session.id) { loadResult in
                switch loadResult {
                case .success(let loadedSession):
                    if let loaded = loadedSession {
                        print("📖 Loaded session: \(loaded.url)")
                        print("⏱️  Duration: \(loaded.duration)s")
                        print("📊 Status: \(loaded.statusCode ?? 0)")
                    }
                case .failure(let error):
                    print("❌ Failed to load session: \(error)")
                }
            }
            
        case .failure(let error):
            print("❌ Failed to save session: \(error)")
        }
    }
    
    // Get storage statistics
    NetworkMonitorAPI.getSessionCount { result in
        switch result {
        case .success(let count):
            print("📊 Total sessions in storage: \(count)")
        case .failure(let error):
            print("❌ Failed to get session count: \(error)")
        }
    }
}

// MARK: - Filtering Examples

/// Example 3: Basic filtering
func example3_BasicFiltering() {
    print("\n=== Example 3: Basic Filtering ===")
    
    let storage = NetworkMonitorAPI.defaultStorage
    
    // Create filter for successful API requests
    let successfulAPIFilter = FilterCriteria()
        .host(pattern: "api.example.com")
        .statusCategory(.success)
    
    // Apply the filter
    storage.load(matching: successfulAPIFilter) { result in
        switch result {
        case .success(let sessions):
            print("🔍 Found \(sessions.count) successful API requests")
            
            // Print details of each session
            for session in sessions {
                print("  📝 \(session.httpMethod) \(session.url)")
                print("     ⏱️  \(session.duration)s")
                print("     📊 Status: \(session.statusCode ?? 0)")
            }
            
        case .failure(let error):
            print("❌ Filtering failed: \(error)")
        }
    }
    
    // Example: Filter slow requests (over 1 second)
    let slowRequestsFilter = FilterCriteria()
        .duration(min: 1.0, max: 10.0)
    
    storage.load(matching: slowRequestsFilter) { result in
        switch result {
        case .success(let sessions):
            print("🐌 Found \(sessions.count) slow requests")
        case .failure(let error):
            print("❌ Slow requests filter failed: \(error)")
        }
    }
}

// MARK: - Search Examples

/// Example 4: Basic search functionality
func example4_BasicSearch() {
    print("\n=== Example 4: Basic Search ===")
    
    let storage = NetworkMonitorAPI.defaultStorage
    
    // Load all sessions for searching
    storage.loadAll { result in
        switch result {
        case .success(let sessions):
            print("📚 Loaded \(sessions.count) sessions for searching")
            
            // Simple text search
            NetworkMonitorAPI.quickSearch(text: "example.com", in: sessions) { searchResult in
                switch searchResult {
                case .success(let matchingSessions):
                    print("🔍 Found \(matchingSessions.count) sessions matching 'example.com'")
                    
                    for session in matchingSessions {
                        print("  📝 \(session.httpMethod) \(session.url)")
                    }
                    
                case .failure(let error):
                    print("❌ Search failed: \(error)")
                }
            }
            
            // Search by host
            NetworkMonitorAPI.quickSearchByHost("api.example.com", in: sessions) { searchResult in
                switch searchResult {
                case .success(let result):
                    print("🏠 Found \(result.matchCount) sessions for host 'api.example.com'")
                    print("⏱️  Search took \(String(format: "%.3f", result.searchTime))s")
                    
                case .failure(let error):
                    print("❌ Host search failed: \(error)")
                }
            }
            
        case .failure(let error):
            print("❌ Failed to load sessions: \(error)")
        }
    }
}

// MARK: - Advanced Filtering Example

/// Example 5: Advanced filtering with multiple conditions
func example5_AdvancedFiltering() {
    print("\n=== Example 5: Advanced Filtering ===")
    
    let storage = NetworkMonitorAPI.defaultStorage
    
    // Complex filter: JSON API calls that were successful and took between 0.1-2.0 seconds
    let complexFilter = FilterCriteria()
        .contentType("application/json")
        .statusCategory(.success)
        .duration(min: 0.1, max: 2.0)
        .host(pattern: "api\\.", isRegex: true) // Regex for hosts starting with "api."
    
    storage.load(matching: complexFilter) { result in
        switch result {
        case .success(let sessions):
            print("🔬 Advanced filter found \(sessions.count) sessions")
            
            if !sessions.isEmpty {
                // Calculate average duration
                let avgDuration = sessions.compactMap { $0.response?.duration }.reduce(0, +) / Double(sessions.count)
                print("⏱️  Average duration: \(String(format: "%.2f", avgDuration))s")
                
                // Group by HTTP method
                let methodGroups = Dictionary(grouping: sessions, by: { $0.httpMethod })
                for (method, sessions) in methodGroups {
                    print("📊 \(method): \(sessions.count) requests")
                }
            }
            
        case .failure(let error):
            print("❌ Advanced filtering failed: \(error)")
        }
    }
}

// MARK: - Memory Management Example

/// Example 6: Storage memory management
func example6_MemoryManagement() {
    print("\n=== Example 6: Memory Management ===")
    
    let memoryStorage = NetworkMonitorAPI.defaultStorage
    
    // Check current memory usage
    let stats = NetworkMonitorAPI.getMemoryStatistics()
    print("📊 Memory Statistics:")
    print("   Sessions: \(stats.sessionCount)/\(stats.maxSessions)")
    print("   Memory: \(stats.humanReadableMemoryUsage)")
    print("   Usage: \(String(format: "%.1f", stats.sessionCountRatio * 100))%")
    
    // If memory usage is high, demonstrate cleanup
    if stats.sessionCountRatio > 0.7 {
        print("⚠️  Memory usage is high, performing cleanup...")
        
        // Manual cleanup of old sessions
        memoryStorage.performManualCleanup { result in
            switch result {
            case .success(let cleanedCount):
                print("🧹 Cleaned up \(cleanedCount) old sessions")
                
                // Check stats again
                let newStats = NetworkMonitorAPI.getMemoryStatistics()
                print("📊 After cleanup: \(newStats.sessionCount) sessions")
                
            case .failure(let error):
                print("❌ Cleanup failed: \(error)")
            }
        }
    }
    
    // Clear all sessions if needed
    if stats.sessionCount > 100 {
        print("🗑️  Too many sessions, clearing all...")
        
        NetworkMonitorAPI.clearAllSessions { result in
            switch result {
            case .success():
                print("✅ All sessions cleared")
            case .failure(let error):
                print("❌ Failed to clear sessions: \(error)")
            }
        }
    }
}

// MARK: - Error Handling Example

/// Example 7: Proper error handling patterns
func example7_ErrorHandling() {
    print("\n=== Example 7: Error Handling ===")
    
    // Demonstrate safety checks for release builds
    let safetyResult = NetworkMonitor.shared.performSafetyCheck()
    
    switch safetyResult {
    case .success():
        print("✅ Safety check passed, monitoring can be enabled")
        
        // Start with safety confirmation
        let startResult = NetworkMonitor.shared.startWithSafetyConfirmation(confirmReleaseUsage: false)
        
        switch startResult {
        case .success():
            print("✅ Monitoring started safely")
        case .failure(let error):
            print("⚠️  Monitoring start failed: \(error.localizedDescription)")
            
            // Handle specific error types
            switch error {
            case .releaseMonitoringBlocked:
                print("💡 Tip: Set NetworkMonitor.allowReleaseMonitoring = true to override (not recommended for production)")
            case .releaseUsageNotConfirmed:
                print("💡 Tip: Pass confirmReleaseUsage: true if you really want to monitor in release builds")
            case .startupFailed:
                print("💡 Tip: Check system permissions and resource availability")
            }
        }
        
    case .failure(let error):
        print("❌ Safety check failed: \(error.localizedDescription)")
    }
    
    // Demonstrate graceful handling of storage errors
    let storage = NetworkMonitorAPI.defaultStorage
    
    // Try to load a non-existent session
    let nonExistentID = UUID()
    storage.load(sessionID: nonExistentID) { result in
        switch result {
        case .success(let session):
            if session == nil {
                print("📭 Session not found (this is expected)")
            } else {
                print("📖 Found session: \(session!.url)")
            }
        case .failure(let error):
            print("❌ Unexpected error loading session: \(error)")
        }
    }
}

// MARK: - Running All Examples

/// Run all examples in sequence
func runAllExamples() {
    print("🚀 NetworkMonitor Basic Usage Examples")
    print("=====================================")
    
    example1_GettingStarted()
    
    // Add small delay between examples to avoid overwhelming output
    Thread.sleep(forTimeInterval: 0.1)
    
    example2_BasicStorage()
    Thread.sleep(forTimeInterval: 0.1)
    
    example3_BasicFiltering()
    Thread.sleep(forTimeInterval: 0.1)
    
    example4_BasicSearch()
    Thread.sleep(forTimeInterval: 0.1)
    
    example5_AdvancedFiltering()
    Thread.sleep(forTimeInterval: 0.1)
    
    example6_MemoryManagement()
    Thread.sleep(forTimeInterval: 0.1)
    
    example7_ErrorHandling()
    
    print("\n✅ All examples completed!")
    print("📚 Check each example function for detailed implementation")
}

// MARK: - Usage Notes

/*
 Usage Notes:
 
 1. Copy the functions you need into your project
 2. Modify the examples to match your specific use cases
 3. Remember to handle errors appropriately in production code
 4. Test thoroughly before using in production apps
 5. Consider the security implications of network monitoring in release builds
 
 For more advanced examples, see:
 - UsageExamples.swift for comprehensive patterns
 - PublicAPI.swift for the full API reference
 - Test files for detailed usage patterns
 */