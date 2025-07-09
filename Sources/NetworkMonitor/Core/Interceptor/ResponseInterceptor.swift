import Foundation

/// Intercepts HTTP responses for monitoring
internal class ResponseInterceptor {
    
    // MARK: - Properties
    
    /// Reference to the network monitor
    private weak var monitor: NetworkMonitor?
    
    /// Configuration for interception
    private let configuration: NetworkMonitor.Configuration
    
    /// Whether the interceptor is currently active
    private var isActive: Bool = false
    
    /// Queue for processing intercepted responses
    private let interceptorQueue = DispatchQueue(label: "com.networkmonitor.response.interceptor", qos: .utility)
    
    /// Session ID mapping for correlating requests and responses
    private var sessionIdMapping: [URLSessionTask: UUID] = [:]
    
    /// Lock for thread-safe access to session mapping
    private let mappingLock = NSLock()
    
    // MARK: - Initialization
    
    init(monitor: NetworkMonitor, configuration: NetworkMonitor.Configuration) {
        self.monitor = monitor
        self.configuration = configuration
    }
    
    // MARK: - Lifecycle Methods
    
    /// Starts response interception
    func start() {
        interceptorQueue.async {
            guard !self.isActive else { return }
            
            self.setupResponseInterception()
            self.isActive = true
        }
    }
    
    /// Stops response interception
    func stop() {
        interceptorQueue.async {
            guard self.isActive else { return }
            
            self.teardownResponseInterception()
            self.isActive = false
            
            // Clear session mapping
            self.mappingLock.lock()
            self.sessionIdMapping.removeAll()
            self.mappingLock.unlock()
        }
    }
    
    // MARK: - Interception Methods
    
    /// Associates a URLSessionTask with a session ID
    /// - Parameters:
    ///   - task: The URLSessionTask
    ///   - sessionId: The session ID to associate
    func associateTask(_ task: URLSessionTask, with sessionId: UUID) {
        mappingLock.lock()
        sessionIdMapping[task] = sessionId
        mappingLock.unlock()
    }
    
    /// Intercepts an HTTP response
    /// - Parameters:
    ///   - task: The URLSessionTask that completed
    ///   - response: The URLResponse received
    ///   - data: The response data
    ///   - error: Any error that occurred
    func interceptResponse(
        for task: URLSessionTask,
        response: URLResponse?,
        data: Data?,
        error: Error?
    ) {
        guard isActive, let monitor = monitor else { return }
        
        // Get session ID for this task
        mappingLock.lock()
        let sessionId = sessionIdMapping[task]
        sessionIdMapping.removeValue(forKey: task)
        mappingLock.unlock()
        
        guard let sessionId = sessionId else { return }
        
        if let error = error {
            // Handle error case
            monitor.failSession(sessionId, with: error)
        } else if let httpResponse = response as? HTTPURLResponse {
            // Convert to HTTPResponse and update session
            let networkResponse = convertToHTTPResponse(
                httpResponse,
                data: data,
                task: task
            )
            monitor.updateSession(sessionId, with: networkResponse)
        }
    }
    
    // MARK: - Private Methods
    
    /// Sets up response interception mechanisms
    private func setupResponseInterception() {
        #if DEBUG
        // Note: This is a conceptual implementation
        // In a real implementation, you would use URLSessionDelegate,
        // URLProtocol, or method swizzling to intercept responses
        #endif
    }
    
    /// Tears down response interception mechanisms
    private func teardownResponseInterception() {
        #if DEBUG
        // Clean up any interception mechanisms
        #endif
    }
    
    /// Converts URLResponse and data to HTTPResponse
    /// - Parameters:
    ///   - httpResponse: The HTTPURLResponse
    ///   - data: The response data
    ///   - task: The URLSessionTask (for timing information)
    /// - Returns: Converted HTTPResponse
    private func convertToHTTPResponse(
        _ httpResponse: HTTPURLResponse,
        data: Data?,
        task: URLSessionTask
    ) -> HTTPResponse {
        
        // Extract headers
        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                headers[keyString] = valueString
            }
        }
        
        // Process response body if enabled
        var responseBody: Data?
        if configuration.captureResponseBodies, let data = data {
            if data.count <= configuration.maxBodySize {
                responseBody = data
            } else {
                responseBody = data.prefix(configuration.maxBodySize)
            }
        }
        
        // Calculate duration from task metrics if available
        let duration = calculateTaskDuration(task)
        
        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            body: responseBody,
            duration: duration
        )
    }
    
    /// Calculates the duration of a URLSessionTask
    /// - Parameter task: The URLSessionTask
    /// - Returns: Duration in seconds
    private func calculateTaskDuration(_ task: URLSessionTask) -> TimeInterval {
        // In iOS 10+, we can access task metrics for precise timing
        if #available(iOS 10.0, macOS 10.12, tvOS 10.0, watchOS 3.0, *) {
            // This would require access to URLSessionTaskMetrics
            // For now, we'll return a default value
            return 0.0
        }
        
        // Fallback for older systems
        return 0.0
    }
}

// MARK: - URLSessionTaskDelegate Extensions

/// Extension to help with manual URLSessionTaskDelegate integration
public extension URLSessionTaskDelegate where Self: NSObject {
    
    /// Call this method from your URLSessionTaskDelegate to enable monitoring
    /// - Parameters:
    ///   - task: The URLSessionTask that completed
    ///   - error: Any error that occurred
    func networkMonitorDidCompleteTask(_ task: URLSessionTask, error: Error?) {
        guard NetworkMonitor.shared.isActive() else { return }
        
        // This would be called by the response interceptor
        // The actual implementation would depend on how the delegate is set up
    }
}

// MARK: - URLSessionDataDelegate Extensions

/// Extension to help with manual URLSessionDataDelegate integration
public extension URLSessionDataDelegate where Self: NSObject {
    
    /// Call this method from your URLSessionDataDelegate to enable monitoring
    /// - Parameters:
    ///   - task: The URLSessionDataTask
    ///   - data: The data received
    func networkMonitorDidReceiveData(_ task: URLSessionDataTask, data: Data) {
        guard NetworkMonitor.shared.isActive() else { return }
        
        // This would be called by the response interceptor
        // The actual implementation would depend on how the delegate is set up
    }
}