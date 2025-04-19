import Foundation

/// NetworkMonitor is a library for monitoring, analyzing, and filtering network traffic in iOS, macOS, watchOS, and tvOS applications.
public final class NetworkMonitor {
    
    /// Shared instance of NetworkMonitor
    public static let shared = NetworkMonitor()
    
    /// Private initializer to enforce singleton pattern
    private init() {}
    
    /// Flag indicating whether monitoring is active
    private var isMonitoring = false
    
    /// Starts monitoring network traffic
    public func start() {
        // This will be implemented in future issues
        isMonitoring = true
    }
    
    /// Stops monitoring network traffic
    public func stop() {
        // This will be implemented in future issues
        isMonitoring = false
    }
    
    /// Returns whether the monitor is currently active
    public func isActive() -> Bool {
        return isMonitoring
    }
    
    /// Version of the NetworkMonitor library
    public static let version = "0.1.0"
} 