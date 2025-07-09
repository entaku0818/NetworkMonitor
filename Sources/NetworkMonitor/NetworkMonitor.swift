import Foundation

/// NetworkMonitor is a library for monitoring, analyzing, and filtering network traffic in iOS, macOS, watchOS, and tvOS applications.
public final class NetworkMonitor {
    
    /// Build configuration for production safety
    public enum BuildConfiguration {
        case debug
        case release
        
        /// Current build configuration
        public static var current: BuildConfiguration {
            #if DEBUG
            return .debug
            #else
            return .release
            #endif
        }
    }
    
    /// Monitoring state
    public enum MonitoringState {
        case active
        case inactive
        case disabled(reason: String)
    }
    
    /// Shared instance of NetworkMonitor
    public static let shared = NetworkMonitor()
    
    /// Private initializer to enforce singleton pattern
    private init() {
        // Check if monitoring should be disabled in release builds
        if BuildConfiguration.current == .release && !Self.allowReleaseMonitoring {
            state = .disabled(reason: "Monitoring is disabled in release builds for security reasons")
            logSecurityMessage("⚠️  NetworkMonitor is disabled in release builds")
        } else {
            state = .inactive
        }
    }
    
    /// Current monitoring state
    private var state: MonitoringState = .inactive
    
    /// Override flag to allow monitoring in release builds (use with extreme caution)
    public static var allowReleaseMonitoring: Bool = false
    
    /// Starts monitoring network traffic
    public func start() {
        switch state {
        case .disabled(let reason):
            logSecurityMessage("❌ Cannot start monitoring: \(reason)")
            return
            
        case .active:
            logSecurityMessage("⚠️  Monitoring is already active")
            return
            
        case .inactive:
            // Additional safety checks
            if BuildConfiguration.current == .release {
                guard Self.allowReleaseMonitoring else {
                    logSecurityMessage("🚫 Monitoring blocked in release build. Set NetworkMonitor.allowReleaseMonitoring = true to override (NOT recommended)")
                    state = .disabled(reason: "Release build monitoring is blocked")
                    return
                }
                
                // Log warning if release monitoring is explicitly enabled
                logSecurityMessage("⚠️  WARNING: Network monitoring is enabled in RELEASE build - this may expose sensitive data")
                logSecurityMessage("⚠️  Ensure this is intentional and remove before App Store submission")
            }
            
            // This will be implemented in future issues
            state = .active
            logSecurityMessage("✅ Network monitoring started")
        }
    }
    
    /// Stops monitoring network traffic
    public func stop() {
        switch state {
        case .disabled:
            logSecurityMessage("ℹ️  Monitoring is already disabled")
            return
            
        case .inactive:
            logSecurityMessage("ℹ️  Monitoring is already inactive")
            return
            
        case .active:
            // This will be implemented in future issues
            state = .inactive
            logSecurityMessage("🛑 Network monitoring stopped")
        }
    }
    
    /// Returns whether the monitor is currently active
    public func isActive() -> Bool {
        switch state {
        case .active:
            return true
        case .inactive, .disabled:
            return false
        }
    }
    
    /// Returns the current monitoring state
    public func monitoringState() -> MonitoringState {
        return state
    }
    
    /// Version of the NetworkMonitor library
    public static let version = "0.1.0"
    
    /// Build information
    public static let buildInfo: [String: Any] = [
        "version": version,
        "buildConfiguration": BuildConfiguration.current == .debug ? "debug" : "release",
        "isDebugBuild": BuildConfiguration.current == .debug,
        "releaseMonitoringAllowed": allowReleaseMonitoring
    ]
    
    // MARK: - Private Methods
    
    /// Logs security-related messages
    private func logSecurityMessage(_ message: String) {
        #if DEBUG
        print("🔐 NetworkMonitor: \(message)")
        #endif
    }
}

// MARK: - Safety Extensions

public extension NetworkMonitor {
    
    /// Performs a safety check before enabling monitoring
    /// - Returns: Result indicating whether monitoring can be safely enabled
    func performSafetyCheck() -> Result<Void, NetworkMonitorError> {
        switch BuildConfiguration.current {
        case .debug:
            return .success(())
            
        case .release:
            if Self.allowReleaseMonitoring {
                return .success(())
            } else {
                return .failure(.releaseMonitoringBlocked)
            }
        }
    }
    
    /// Enables monitoring with explicit safety confirmation
    /// - Parameter confirmReleaseUsage: Must be true to enable in release builds
    /// - Returns: Result indicating success or failure
    func startWithSafetyConfirmation(confirmReleaseUsage: Bool = false) -> Result<Void, NetworkMonitorError> {
        if BuildConfiguration.current == .release && !confirmReleaseUsage {
            return .failure(.releaseUsageNotConfirmed)
        }
        
        if BuildConfiguration.current == .release {
            Self.allowReleaseMonitoring = true
        }
        
        start()
        
        if isActive() {
            return .success(())
        } else {
            return .failure(.startupFailed)
        }
    }
    
    /// Force disables monitoring and clears any stored data
    func forceDisable() {
        stop()
        state = .disabled(reason: "Monitoring was force disabled")
        Self.allowReleaseMonitoring = false
        logSecurityMessage("🔒 Network monitoring force disabled")
    }
}

// MARK: - Error Types

public enum NetworkMonitorError: Error, LocalizedError {
    case releaseMonitoringBlocked
    case releaseUsageNotConfirmed
    case startupFailed
    
    public var errorDescription: String? {
        switch self {
        case .releaseMonitoringBlocked:
            return "Network monitoring is blocked in release builds for security reasons"
        case .releaseUsageNotConfirmed:
            return "Release usage must be explicitly confirmed to enable monitoring"
        case .startupFailed:
            return "Failed to start network monitoring"
        }
    }
}

// MARK: - Compile-time Safety

#if !DEBUG
// Additional compile-time warnings for release builds
#warning("⚠️  NetworkMonitor is included in a release build - ensure this is intentional")
#warning("⚠️  Remove NetworkMonitor from release builds before App Store submission")
#endif 