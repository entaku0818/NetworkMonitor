# NetworkMonitor Installation Guide

This guide provides comprehensive instructions for installing and integrating NetworkMonitor into your iOS, macOS, watchOS, and tvOS projects.

## Table of Contents

- [System Requirements](#system-requirements)
- [Installation Methods](#installation-methods)
  - [Swift Package Manager (Recommended)](#swift-package-manager-recommended)
  - [CocoaPods](#cocoapods)
  - [Carthage](#carthage)
  - [Manual Installation](#manual-installation)
- [Platform-Specific Setup](#platform-specific-setup)
- [First Integration](#first-integration)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

## System Requirements

### Minimum Requirements
- **iOS**: 13.0+
- **macOS**: 10.15+
- **watchOS**: 6.0+
- **tvOS**: 13.0+
- **Xcode**: 12.0+
- **Swift**: 5.3+

### Recommended Environment
- **Xcode**: 14.0+ (for best development experience)
- **Swift**: 5.7+
- **iOS**: 15.0+ (for latest features)

## Installation Methods

### Swift Package Manager (Recommended)

Swift Package Manager is the recommended way to integrate NetworkMonitor into your project.

#### Option 1: Xcode GUI

1. **Open your project in Xcode**
2. **Navigate to File → Add Package Dependencies...**
3. **Enter the repository URL:**
   ```
   https://github.com/entaku0818/NetworkMonitor.git
   ```
4. **Select version requirements:**
   - **Exact Version**: Choose a specific version (e.g., `0.1.0`)
   - **Up to Next Major**: Recommended for latest features
   - **Up to Next Minor**: For more stability
5. **Click "Add Package"**
6. **Select your target(s)** and click "Add Package"

#### Option 2: Package.swift

If you're building a Swift package, add NetworkMonitor to your `Package.swift` file:

```swift
// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "YourProject",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/entaku0818/NetworkMonitor.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "YourProject",
            dependencies: ["NetworkMonitor"]
        )
    ]
)
```

Then run:
```bash
swift package resolve
```

### CocoaPods

Add NetworkMonitor to your `Podfile`:

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourApp' do
  pod 'NetworkMonitor', '~> 0.1.0'
end
```

Then install:
```bash
pod install
```

### Carthage

Add NetworkMonitor to your `Cartfile`:

```
github "entaku0818/NetworkMonitor" ~> 0.1.0
```

Then run:
```bash
carthage update --platform iOS
```

Follow the [Carthage integration guide](https://github.com/Carthage/Carthage#quick-start) to add the framework to your project.

### Manual Installation

1. **Download the source code:**
   ```bash
   git clone https://github.com/entaku0818/NetworkMonitor.git
   cd NetworkMonitor
   ```

2. **Add to your project:**
   - Drag the `Sources/NetworkMonitor` folder into your Xcode project
   - Ensure "Copy items if needed" is checked
   - Select your target(s)

3. **Build and verify:**
   - Build your project (⌘+B)
   - Ensure no compilation errors

## Platform-Specific Setup

### iOS Projects

For iOS apps, NetworkMonitor works out of the box with no additional configuration:

```swift
import NetworkMonitor

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Start monitoring
        let result = NetworkMonitorAPI.quickStart()
        if case .failure(let error) = result {
            print("Failed to start monitoring: \\(error)")
        }
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        NetworkMonitorAPI.quickStop()
    }
}
```

### macOS Projects

For macOS apps, ensure your app has appropriate permissions:

```swift
import NetworkMonitor

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NetworkMonitorAPI.quickStart()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        NetworkMonitorAPI.quickStop()
    }
}
```

### watchOS Projects

For watchOS, use a simplified configuration due to memory constraints:

```swift
import NetworkMonitor

@main
struct WatchApp: App {
    init() {
        // Use smaller memory limits for watchOS
        let config = InMemorySessionStorage.Configuration(
            maxSessions: 100,
            maxMemoryUsage: 5 * 1024 * 1024 // 5MB
        )
        let storage = InMemorySessionStorage(configuration: config)
        // Configure your monitoring with this storage
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### tvOS Projects

tvOS setup is similar to iOS:

```swift
import NetworkMonitor

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NetworkMonitorAPI.quickStart()
        return true
    }
}
```

## First Integration

After installation, verify NetworkMonitor is working correctly:

### 1. Basic Import Test

Create a simple test to ensure the framework is properly imported:

```swift
import NetworkMonitor

class NetworkTest {
    func testBasicFunctionality() {
        // Test 1: Check version
        print("NetworkMonitor version: \\(NetworkMonitor.version)")
        
        // Test 2: Create storage
        let storage = InMemorySessionStorage()
        print("Storage created successfully")
        
        // Test 3: Create a sample session
        let request = HTTPRequest(url: "https://api.example.com/test", method: .get)
        let response = HTTPResponse(statusCode: 200, duration: 0.1)
        let session = HTTPSession(request: request, response: response, state: .completed)
        
        storage.save(session: session) { result in
            switch result {
            case .success():
                print("✅ NetworkMonitor is working correctly!")
            case .failure(let error):
                print("❌ Error: \\(error)")
            }
        }
    }
}
```

### 2. Integration with URLSession

Here's how to integrate NetworkMonitor with your existing networking code:

```swift
import Foundation
import NetworkMonitor

extension URLSession {
    func dataTaskWithMonitoring(with url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let startTime = Date()
        
        return dataTask(with: url) { data, response, error in
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            // Log to NetworkMonitor
            if let httpResponse = response as? HTTPURLResponse {
                let request = HTTPRequest(url: url.absoluteString, method: .get)
                let networkResponse = HTTPResponse(
                    statusCode: httpResponse.statusCode,
                    headers: Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.map { 
                        (String($0.key), String($0.value))
                    }),
                    body: data,
                    duration: duration
                )
                let session = HTTPSession(request: request, response: networkResponse, state: .completed)
                
                NetworkMonitorAPI.defaultStorage.save(session: session) { _ in }
            }
            
            completion(data, response, error)
        }
    }
}

// Usage
let url = URL(string: "https://api.example.com/data")!
URLSession.shared.dataTaskWithMonitoring(with: url) { data, response, error in
    // Handle response
}.resume()
```

### 3. SwiftUI Integration

For SwiftUI apps:

```swift
import SwiftUI
import NetworkMonitor

@main
struct MyApp: App {
    init() {
        NetworkMonitorAPI.quickStart()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    NetworkMonitorAPI.quickStop()
                }
        }
    }
}

struct NetworkDebugView: View {
    @State private var sessionCount = 0
    
    var body: some View {
        VStack {
            Text("Network Sessions: \\(sessionCount)")
            
            Button("Refresh") {
                NetworkMonitorAPI.getSessionCount { result in
                    if case .success(let count) = result {
                        sessionCount = count
                    }
                }
            }
        }
        .onAppear {
            NetworkMonitorAPI.getSessionCount { result in
                if case .success(let count) = result {
                    sessionCount = count
                }
            }
        }
    }
}
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Build Errors

**Error**: `No such module 'NetworkMonitor'`

**Solutions**:
- Ensure you've added NetworkMonitor to your project dependencies
- Clean build folder (⌘+Shift+K) and rebuild
- Check that your deployment target meets minimum requirements
- Verify the framework is added to your target's dependencies

**Error**: `Module compiled with Swift X.X cannot be imported by the Swift Y.Y compiler`

**Solutions**:
- Update to a compatible Swift version
- Use a NetworkMonitor version compatible with your Swift version
- Clean derived data: `~/Library/Developer/Xcode/DerivedData`

#### 2. Runtime Issues

**Issue**: Monitoring not working in release builds

**Solution**:
```swift
// For release builds, explicitly allow monitoring (use with caution)
NetworkMonitor.allowReleaseMonitoring = true
let result = NetworkMonitorAPI.quickStart()
```

**Issue**: High memory usage

**Solutions**:
```swift
// Configure storage limits
let config = InMemorySessionStorage.Configuration(
    maxSessions: 500,  // Reduce from default 1000
    autoCleanup: true,
    retentionPeriod: 30 * 60,  // 30 minutes instead of 1 hour
    maxMemoryUsage: 50 * 1024 * 1024  // 50MB instead of 100MB
)
let storage = InMemorySessionStorage(configuration: config)
```

**Issue**: Performance impact on networking

**Solutions**:
- Use background queues for storage operations
- Enable auto-cleanup to prevent memory accumulation
- Consider using file storage for long-term retention

#### 3. Permission Issues (macOS)

**Issue**: Sandbox restrictions preventing network monitoring

**Solutions**:
- Ensure your app has appropriate entitlements
- For sandboxed apps, add network client entitlement:
  ```xml
  <key>com.apple.security.network.client</key>
  <true/>
  ```

#### 4. watchOS Memory Constraints

**Issue**: App crashes on watchOS due to memory limits

**Solutions**:
```swift
// Use minimal configuration for watchOS
let watchConfig = InMemorySessionStorage.Configuration(
    maxSessions: 50,
    maxMemoryUsage: 2 * 1024 * 1024,  // 2MB
    autoCleanup: true,
    retentionPeriod: 5 * 60  // 5 minutes
)
```

### Performance Optimization

#### 1. Storage Configuration

Choose the right storage type for your needs:

```swift
// For development and debugging
let memoryStorage = InMemorySessionStorage()

// For production with persistence
let fileStorage = FileSessionStorage()

// For hybrid approach
let memoryStorage = InMemorySessionStorage()
let fileStorage = FileSessionStorage()

// Export to file storage when memory is full
memoryStorage.export(to: fileStorage) { result in
    // Handle export completion
}
```

#### 2. Filtering Best Practices

Use efficient filtering to reduce memory usage:

```swift
// Filter at storage level, not after loading all sessions
let recentFilter = FilterCriteria().timestamp(
    from: Date().addingTimeInterval(-3600),  // Last hour only
    to: nil
)

storage.load(matching: recentFilter) { result in
    // Process only recent sessions
}
```

#### 3. Search Optimization

Configure search service for optimal performance:

```swift
let searchConfig = SessionSearchService.SearchConfiguration(
    searchFields: [.url, .host],  // Limit search fields
    maxResults: 100,              // Limit results
    timeout: 2.0                  // Shorter timeout
)
```

### Debug Mode Setup

For development, enable detailed logging:

```swift
#if DEBUG
// Configure for development
let devConfig = InMemorySessionStorage.Configuration(
    maxSessions: 1000,
    autoCleanup: false,  // Manual control during development
    maxMemoryUsage: 100 * 1024 * 1024
)

// Enable performance tracking
let filterEngine = FilterEngine()
filterEngine.isPerformanceTrackingEnabled = true
#endif
```

### App Store Considerations

**Important**: Before submitting to the App Store:

1. **Disable monitoring in release builds**:
   ```swift
   #if DEBUG
   NetworkMonitorAPI.quickStart()
   #endif
   ```

2. **Remove or guard debug interfaces**:
   ```swift
   #if DEBUG
   // Network debug views
   #endif
   ```

3. **Review data collection**: Ensure you're not collecting sensitive user data

4. **Update privacy policy**: Document any network monitoring in your privacy policy

## Advanced Configuration

### Custom Storage Implementation

For specialized needs, implement custom storage:

```swift
class DatabaseSessionStorage: SessionStorageProtocol {
    // Implement protocol methods with database operations
    func save(session: HTTPSession, completion: @escaping (Result<Void, Error>) -> Void) {
        // Save to database
    }
    
    // ... other protocol methods
}
```

### Network Interception

For advanced users, integrate with network interception:

```swift
// This is a conceptual example - actual implementation would depend on your networking stack
class NetworkInterceptor {
    func interceptRequest(_ request: URLRequest) -> URLRequest {
        // Log request start
        let httpRequest = HTTPRequest(from: request)
        let session = HTTPSession(request: httpRequest, state: .sending)
        NetworkMonitorAPI.defaultStorage.save(session: session) { _ in }
        
        return request
    }
    
    func interceptResponse(_ response: URLResponse, data: Data?, error: Error?) {
        // Log response completion
        // Update corresponding session with response data
    }
}
```

### Multi-Environment Setup

Configure different monitoring levels for different environments:

```swift
enum Environment {
    case development
    case staging
    case production
}

func configureNetworkMonitoring(for environment: Environment) {
    switch environment {
    case .development:
        NetworkMonitor.allowReleaseMonitoring = true
        NetworkMonitorAPI.quickStart()
        
    case .staging:
        // Limited monitoring for staging
        let config = InMemorySessionStorage.Configuration(maxSessions: 100)
        // Configure with limited storage
        
    case .production:
        // No monitoring in production
        break
    }
}
```

## Support and Resources

- **Documentation**: Check the README.md and Examples/ directory
- **Sample Code**: See the Examples/ directory for comprehensive examples
- **API Reference**: Use Xcode's Quick Help for detailed API documentation
- **Issues**: Report bugs and feature requests on GitHub

## Security Considerations

- **Never monitor in production** unless absolutely necessary
- **Sanitize sensitive data** before logging
- **Use appropriate retention periods** to limit data exposure
- **Review collected data** to ensure compliance with privacy requirements
- **Implement proper access controls** for debugging interfaces

## Next Steps

After successful installation:

1. **Explore the Examples**: Check the `Examples/` directory for detailed usage patterns
2. **Read the API Documentation**: Review `PublicAPI.swift` for available methods
3. **Integrate with your networking**: Add monitoring to your existing network calls
4. **Configure for your needs**: Adjust storage and search configurations
5. **Test thoroughly**: Verify monitoring works correctly in your app's context

For more detailed examples and advanced usage patterns, see the [Examples README](Examples/README.md).