# NetworkMonitor Examples

This directory contains comprehensive examples and sample code for using NetworkMonitor in your applications.

## Files Overview

### 📚 [BasicUsage.swift](BasicUsage.swift)
Comprehensive examples covering all major features:
- Getting started with NetworkMonitor
- Basic storage operations
- Filtering network sessions
- Search functionality
- Advanced filtering with multiple conditions
- Memory management
- Error handling patterns

### 🚀 [QuickStart.swift](QuickStart.swift)
Minimal code snippets for immediate integration:
- Minimal setup code
- Integration examples for URLSession and Alamofire
- SwiftUI and UIKit app integration
- Unit testing patterns

## Quick Start

### 1. Basic Setup
```swift
import NetworkMonitor

// Start monitoring
let result = NetworkMonitorAPI.quickStart()
if case .success = result {
    print("✅ Monitoring started")
}
```

### 2. Save Network Sessions
```swift
// Create and save a session
let request = HTTPRequest(url: "https://api.example.com/users", method: .get)
let response = HTTPResponse(statusCode: 200, duration: 0.35)
let session = HTTPSession(request: request, response: response, state: .completed)

NetworkMonitorAPI.defaultStorage.save(session: session) { result in
    // Handle result
}
```

### 3. Filter Sessions
```swift
// Filter for successful API calls
let filter = FilterCriteria()
    .host(pattern: "api.example.com")
    .statusCategory(.success)

storage.load(matching: filter) { result in
    // Handle filtered results
}
```

### 4. Search Sessions
```swift
// Simple text search
NetworkMonitorAPI.quickSearch(text: "github", in: sessions) { result in
    // Handle search results
}
```

## Integration Examples

### URLSession Integration
```swift
extension URLSession {
    func dataTaskWithMonitoring(with url: URL) -> URLSessionDataTask {
        let startTime = Date()
        return dataTask(with: url) { data, response, error in
            let duration = Date().timeIntervalSince(startTime)
            // Log to NetworkMonitor
            if let httpResponse = response as? HTTPURLResponse {
                let request = HTTPRequest(url: url.absoluteString, method: .get)
                let networkResponse = HTTPResponse(statusCode: httpResponse.statusCode, duration: duration)
                let session = HTTPSession(request: request, response: networkResponse, state: .completed)
                NetworkMonitorAPI.defaultStorage.save(session: session) { _ in }
            }
        }
    }
}
```

### SwiftUI Integration
```swift
@main
struct MyApp: App {
    init() {
        NetworkMonitorQuickStart.startMonitoring()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    NetworkMonitorQuickStart.stopMonitoring()
                }
        }
    }
}
```

## Advanced Examples

### Custom Filter
```swift
// Complex filter for slow JSON API calls
let complexFilter = FilterCriteria()
    .contentType("application/json")
    .statusCategory(.success)
    .duration(min: 0.5, max: 10.0)
    .host(pattern: "api\\.", isRegex: true)
```

### Advanced Search
```swift
let searchConfig = SessionSearchService.SearchConfiguration(
    useRegex: true,
    searchFields: [.url, .host, .requestHeaders],
    enableHighlights: true
)
let searchService = SessionSearchService(configuration: searchConfig)

let query = SearchQuery(
    text: "user.*not.*found",
    sortBy: .timestamp,
    ascending: false
)

searchService.search(query: query, in: sessions) { result in
    // Handle advanced search results with highlights
}
```

### Memory Management
```swift
// Check memory usage
let stats = NetworkMonitorAPI.getMemoryStatistics()
if stats.sessionCountRatio > 0.8 {
    // Export to file storage if memory is full
    let fileStorage = NetworkMonitorAPI.defaultFileStorage
    memoryStorage.export(to: fileStorage) { result in
        // Handle export result
    }
}
```

## Best Practices

### 1. Security Considerations
- Never enable monitoring in production release builds without careful consideration
- Use `NetworkMonitor.shared.performSafetyCheck()` before starting
- Consider using `startWithSafetyConfirmation()` for explicit control

### 2. Performance
- Use appropriate storage limits in `InMemorySessionStorage.Configuration`
- Enable `autoCleanup` to prevent memory issues
- Consider exporting to file storage for long-term retention

### 3. Error Handling
- Always handle storage operation failures gracefully
- Check monitoring state before performing operations
- Use proper async patterns for all storage operations

### 4. Testing
- Clear storage between tests using `NetworkMonitorAPI.clearAllSessions()`
- Use expectation-based testing for async operations
- Mock network sessions for consistent test data

## Common Use Cases

### 1. Debug Network Issues
```swift
// Find failed requests
let errorFilter = NetworkMonitorAPI.errorRequestsOnly()
storage.load(matching: errorFilter) { result in
    // Analyze failed requests
}
```

### 2. Performance Monitoring
```swift
// Find slow requests
let slowFilter = FilterCriteria().duration(min: 2.0, max: nil)
storage.load(matching: slowFilter) { result in
    // Analyze performance issues
}
```

### 3. API Usage Analysis
```swift
// Analyze API usage patterns
let apiFilter = FilterCriteria().host(pattern: "api\\.", isRegex: true)
storage.load(matching: apiFilter) { result in
    // Generate usage statistics
}
```

### 4. Search Network History
```swift
// Search for specific endpoints
NetworkMonitorAPI.quickSearch(text: "/api/v1/users", in: sessions) { result in
    // Find all calls to users endpoint
}
```

## Running Examples

To run the examples:

1. Copy the relevant example code into your project
2. Import NetworkMonitor
3. Modify the examples to fit your specific needs
4. Test thoroughly before using in production

For more detailed examples, see the individual Swift files in this directory.

## Support

For questions about these examples:
- Check the main NetworkMonitor documentation
- Review the test files for additional usage patterns
- Look at the PublicAPI.swift file for the complete API reference