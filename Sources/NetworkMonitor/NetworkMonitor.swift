import Foundation

/// NetworkMonitor is a library for monitoring, analyzing, and filtering network traffic in iOS, macOS, watchOS, and tvOS applications.
public final class NetworkMonitor {
    
    // MARK: - Types
    
    /// Configuration for network monitoring
    public struct Configuration {
        /// Storage provider for captured sessions
        public let storage: SessionStorageProtocol
        
        /// Whether to automatically capture URLSession traffic
        public let autoInterceptURLSession: Bool
        
        /// Maximum number of concurrent sessions to track
        public let maxConcurrentSessions: Int
        
        /// Whether to capture request/response bodies
        public let captureRequestBodies: Bool
        public let captureResponseBodies: Bool
        
        /// Maximum body size to capture (in bytes)
        public let maxBodySize: Int
        
        /// Notification settings
        public let enableNotifications: Bool
        
        public init(
            storage: SessionStorageProtocol = InMemorySessionStorage(),
            autoInterceptURLSession: Bool = true,
            maxConcurrentSessions: Int = 1000,
            captureRequestBodies: Bool = true,
            captureResponseBodies: Bool = true,
            maxBodySize: Int = 1024 * 1024, // 1MB
            enableNotifications: Bool = true
        ) {
            self.storage = storage
            self.autoInterceptURLSession = autoInterceptURLSession
            self.maxConcurrentSessions = maxConcurrentSessions
            self.captureRequestBodies = captureRequestBodies
            self.captureResponseBodies = captureResponseBodies
            self.maxBodySize = maxBodySize
            self.enableNotifications = enableNotifications
        }
    }
    
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
    
    // MARK: - Properties
    
    /// Current configuration
    private var configuration: Configuration
    
    /// Session manager for tracking active sessions
    private var sessionManager: SessionManager
    
    /// Request interceptor for capturing network traffic
    private var requestInterceptor: RequestInterceptor?
    
    /// Response interceptor for capturing network responses
    private var responseInterceptor: ResponseInterceptor?
    
    /// Currently active sessions being tracked
    private var activeSessions: [UUID: HTTPSession] = [:]
    
    /// Queue for managing session operations
    private let sessionQueue = DispatchQueue(label: "com.networkmonitor.sessions", qos: .utility)
    
    /// Notification manager for session events
    private var notificationManager: NotificationManager?
    
    /// Private initializer to enforce singleton pattern
    private init() {
        self.configuration = Configuration()
        self.sessionManager = SessionManager(storage: self.configuration.storage)
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
            
            // Initialize and start monitoring components
            startMonitoring()
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
            // Stop monitoring components
            stopMonitoring()
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
    
    // MARK: - Configuration Methods
    
    /// Updates the monitor configuration
    /// - Parameter configuration: New configuration to apply
    /// - Note: Can only be updated when monitoring is inactive
    public func updateConfiguration(_ configuration: Configuration) {
        guard !isActive() else {
            logSecurityMessage("⚠️  Cannot update configuration while monitoring is active")
            return
        }
        
        self.configuration = configuration
        self.sessionManager = SessionManager(storage: configuration.storage)
        logSecurityMessage("🔧 Configuration updated")
    }
    
    /// Returns the current configuration
    public func getConfiguration() -> Configuration {
        return configuration
    }
    
    // MARK: - Session Management Methods
    
    /// Starts a new session for tracking
    /// - Parameter request: The HTTP request that started the session
    /// - Returns: The created session ID
    public func startSession(for request: HTTPRequest) -> UUID {
        let session = HTTPSession(request: request, state: .sending)
        
        sessionQueue.async {
            self.activeSessions[session.id] = session
            self.sessionManager.addSession(session)
            
            // Notify observers
            self.notificationManager?.sessionStarted(session)
        }
        
        return session.id
    }
    
    /// Updates a session with response data
    /// - Parameters:
    ///   - sessionId: The session ID to update
    ///   - response: The HTTP response received
    public func updateSession(_ sessionId: UUID, with response: HTTPResponse) {
        sessionQueue.async {
            guard let session = self.activeSessions[sessionId] else { return }
            
            // Create completed session
            let completedSession = session.completed(response: response)
            
            self.activeSessions[sessionId] = completedSession
            self.sessionManager.updateSession(completedSession)
            
            // Save to storage
            self.configuration.storage.save(session: completedSession) { result in
                switch result {
                case .success():
                    self.logSecurityMessage("📝 Session saved: \(completedSession.httpMethod) \(completedSession.url)")
                case .failure(let error):
                    self.logSecurityMessage("❌ Failed to save session: \(error)")
                }
            }
            
            // Clean up from active sessions
            self.activeSessions.removeValue(forKey: sessionId)
            
            // Notify observers
            self.notificationManager?.sessionCompleted(completedSession)
        }
    }
    
    /// Marks a session as failed
    /// - Parameters:
    ///   - sessionId: The session ID to mark as failed
    ///   - error: The error that occurred
    public func failSession(_ sessionId: UUID, with error: Error) {
        sessionQueue.async {
            guard let session = self.activeSessions[sessionId] else { return }
            
            // Create failed session
            let failedSession = session.failed(error: error)
            
            self.activeSessions[sessionId] = failedSession
            self.sessionManager.updateSession(failedSession)
            
            // Save to storage
            self.configuration.storage.save(session: failedSession) { _ in }
            
            // Clean up from active sessions
            self.activeSessions.removeValue(forKey: sessionId)
            
            // Notify observers
            self.notificationManager?.sessionFailed(failedSession, error: error)
        }
    }
    
    /// Returns the count of currently active sessions
    public func getActiveSessionCount() -> Int {
        return sessionQueue.sync {
            return activeSessions.count
        }
    }
    
    /// Returns all currently active sessions
    public func getActiveSessions() -> [HTTPSession] {
        return sessionQueue.sync {
            return Array(activeSessions.values)
        }
    }
    
    // MARK: - Private Methods
    
    /// Starts the monitoring components
    private func startMonitoring() {
        // Initialize session manager
        sessionManager.start()
        
        // Initialize notification manager if enabled
        if configuration.enableNotifications {
            notificationManager = NotificationManager()
        }
        
        // Initialize interceptors if auto-interception is enabled
        if configuration.autoInterceptURLSession {
            startURLSessionInterception()
        }
        
        logSecurityMessage("🚀 Monitoring components started")
    }
    
    /// Stops the monitoring components
    private func stopMonitoring() {
        // Stop session manager
        sessionManager.stop()
        
        // Stop interceptors
        stopURLSessionInterception()
        
        // Clear active sessions
        sessionQueue.async {
            self.activeSessions.removeAll()
        }
        
        // Clear notification manager
        notificationManager = nil
        
        logSecurityMessage("🛑 Monitoring components stopped")
    }
    
    /// Starts URLSession traffic interception
    private func startURLSessionInterception() {
        requestInterceptor = RequestInterceptor(monitor: self, configuration: configuration)
        responseInterceptor = ResponseInterceptor(monitor: self, configuration: configuration)
        
        requestInterceptor?.start()
        responseInterceptor?.start()
        
        logSecurityMessage("🔍 URLSession interception started")
    }
    
    /// Stops URLSession traffic interception
    private func stopURLSessionInterception() {
        requestInterceptor?.stop()
        responseInterceptor?.stop()
        
        requestInterceptor = nil
        responseInterceptor = nil
        
        logSecurityMessage("🔍 URLSession interception stopped")
    }
    
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