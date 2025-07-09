import Foundation

/// Intercepts HTTP requests for monitoring
internal class RequestInterceptor {
    
    // MARK: - Properties
    
    /// Reference to the network monitor
    private weak var monitor: NetworkMonitor?
    
    /// Configuration for interception
    private let configuration: NetworkMonitor.Configuration
    
    /// Whether the interceptor is currently active
    private var isActive: Bool = false
    
    /// Queue for processing intercepted requests
    private let interceptorQueue = DispatchQueue(label: "com.networkmonitor.request.interceptor", qos: .utility)
    
    /// Original URLSession method implementations (for swizzling)
    private var originalDataTaskMethod: Method?
    private var originalUploadTaskMethod: Method?
    private var originalDownloadTaskMethod: Method?
    
    // MARK: - Initialization
    
    init(monitor: NetworkMonitor, configuration: NetworkMonitor.Configuration) {
        self.monitor = monitor
        self.configuration = configuration
    }
    
    // MARK: - Lifecycle Methods
    
    /// Starts request interception
    func start() {
        interceptorQueue.async {
            guard !self.isActive else { return }
            
            self.setupURLSessionInterception()
            self.isActive = true
        }
    }
    
    /// Stops request interception
    func stop() {
        interceptorQueue.async {
            guard self.isActive else { return }
            
            self.teardownURLSessionInterception()
            self.isActive = false
        }
    }
    
    // MARK: - Interception Methods
    
    /// Intercepts an HTTP request
    /// - Parameter urlRequest: The URLRequest being made
    /// - Returns: Session ID for tracking the request
    func interceptRequest(_ urlRequest: URLRequest) -> UUID? {
        guard isActive, let monitor = monitor else { return nil }
        
        // Convert URLRequest to HTTPRequest
        let httpRequest = convertToHTTPRequest(urlRequest)
        
        // Start session tracking
        let sessionId = monitor.startSession(for: httpRequest)
        
        return sessionId
    }
    
    // MARK: - Private Methods
    
    /// Sets up URLSession method swizzling for request interception
    private func setupURLSessionInterception() {
        #if DEBUG
        // Note: This is a conceptual implementation
        // In a real implementation, you would use method swizzling or URLProtocol
        // to intercept URLSession traffic
        
        guard let urlSessionClass = NSClassFromString("NSURLSession") else { return }
        
        // Store original method implementations
        let dataTaskSelector = Selector(("dataTask:withRequest:"))
        if let dataTaskMethod = class_getInstanceMethod(urlSessionClass, dataTaskSelector) {
            originalDataTaskMethod = dataTaskMethod
        }
        
        // In a full implementation, you would swizzle the methods here
        // This is just a placeholder for the concept
        #endif
    }
    
    /// Tears down URLSession method swizzling
    private func teardownURLSessionInterception() {
        #if DEBUG
        // Restore original method implementations if they were swizzled
        // This is just a placeholder for the concept
        #endif
    }
    
    /// Converts a URLRequest to HTTPRequest
    /// - Parameter urlRequest: The URLRequest to convert
    /// - Returns: Converted HTTPRequest
    private func convertToHTTPRequest(_ urlRequest: URLRequest) -> HTTPRequest {
        let method = HTTPRequest.Method(rawValue: urlRequest.httpMethod ?? "GET") ?? .get
        let url = urlRequest.url?.absoluteString ?? ""
        
        // Extract headers
        var headers: [String: String] = [:]
        if let allHTTPHeaderFields = urlRequest.allHTTPHeaderFields {
            headers = allHTTPHeaderFields
        }
        
        // Extract body if enabled
        var body: Data?
        if configuration.captureRequestBodies {
            body = urlRequest.httpBody
            
            // Limit body size if configured
            if let bodyData = body, bodyData.count > configuration.maxBodySize {
                body = bodyData.prefix(configuration.maxBodySize)
            }
        }
        
        return HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: body
        )
    }
}

// MARK: - URLSession Extension for Manual Integration

public extension URLSession {
    
    /// Creates a data task with NetworkMonitor integration
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - completionHandler: Completion handler for the task
    /// - Returns: URLSessionDataTask with monitoring
    func dataTaskWithMonitoring(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        
        let startTime = Date()
        let sessionId = NetworkMonitor.shared.startSession(for: HTTPRequest.from(request))
        
        return dataTask(with: request) { data, response, error in
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            if let error = error {
                NetworkMonitor.shared.failSession(sessionId, with: error)
            } else if let httpResponse = response as? HTTPURLResponse {
                let networkResponse = HTTPResponse.from(httpResponse, data: data, duration: duration)
                NetworkMonitor.shared.updateSession(sessionId, with: networkResponse)
            }
            
            completionHandler(data, response, error)
        }
    }
    
    /// Creates a data task with NetworkMonitor integration (async/await version)
    /// - Parameter request: The URLRequest to execute
    /// - Returns: Tuple containing data and response
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func dataWithMonitoring(for request: URLRequest) async throws -> (Data, URLResponse) {
        let startTime = Date()
        let sessionId = NetworkMonitor.shared.startSession(for: HTTPRequest.from(request))
        
        do {
            let (data, response) = try await data(for: request)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                let networkResponse = HTTPResponse.from(httpResponse, data: data, duration: duration)
                NetworkMonitor.shared.updateSession(sessionId, with: networkResponse)
            }
            
            return (data, response)
        } catch {
            NetworkMonitor.shared.failSession(sessionId, with: error)
            throw error
        }
    }
}