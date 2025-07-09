import Foundation

/// URLProtocol subclass for intercepting network requests in NetworkMonitor
/// This provides automatic network traffic capture for URLSession requests
public class NetworkMonitorURLProtocol: URLProtocol {
    
    // MARK: - Properties
    
    /// Key for storing session ID in URLRequest properties
    private static let sessionIdKey = "NetworkMonitorSessionId"
    
    /// Key for storing start time in URLRequest properties
    private static let startTimeKey = "NetworkMonitorStartTime"
    
    /// Internal URLSessionDataTask for handling the actual request
    private var dataTask: URLSessionDataTask?
    
    /// Session ID for this request
    private var sessionId: UUID?
    
    /// Start time of the request
    private var startTime: Date?
    
    /// Accumulated response data
    private var responseData = Data()
    
    // MARK: - URLProtocol Override Methods
    
    /// Determines if this protocol can handle the given request
    /// - Parameter request: The URLRequest to evaluate
    /// - Returns: true if NetworkMonitor is active and should intercept this request
    public override class func canInit(with request: URLRequest) -> Bool {
        // Only handle requests when NetworkMonitor is active
        guard NetworkMonitor.shared.isActive() else { return false }
        
        // Avoid infinite loops by checking if we've already handled this request
        guard property(forKey: sessionIdKey, in: request) == nil else { return false }
        
        // Only handle HTTP/HTTPS requests
        guard let scheme = request.url?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return false }
        
        return true
    }
    
    /// Returns the canonical version of the request
    /// - Parameter request: The original request
    /// - Returns: The canonical request (unchanged in this implementation)
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    /// Determines if two requests are equivalent for caching purposes
    /// - Parameters:
    ///   - a: First request
    ///   - b: Second request
    /// - Returns: true if requests are equivalent
    public override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, to: b)
    }
    
    /// Starts loading the request
    public override func startLoading() {
        // Create a mutable copy of the request to add properties
        let mutableRequest = NSMutableURLRequest(url: request.url!, cachePolicy: request.cachePolicy, timeoutInterval: request.timeoutInterval)
        mutableRequest.httpMethod = request.httpMethod ?? "GET"
        mutableRequest.allHTTPHeaderFields = request.allHTTPHeaderFields
        mutableRequest.httpBody = request.httpBody
        
        // Generate session ID and start time
        let sessionId = UUID()
        let startTime = Date()
        
        // Store properties in the request
        Self.setProperty(sessionId.uuidString, forKey: Self.sessionIdKey, in: mutableRequest)
        Self.setProperty(startTime, forKey: Self.startTimeKey, in: mutableRequest)
        
        // Store locally for use in delegate methods
        self.sessionId = sessionId
        self.startTime = startTime
        
        // Start session in NetworkMonitor
        let httpRequest = HTTPRequest.from(request)
        let actualSessionId = NetworkMonitor.shared.startSession(for: httpRequest)
        self.sessionId = actualSessionId
        
        // Create URLSession configuration that doesn't use this protocol
        let config = URLSessionConfiguration.default
        config.protocolClasses = config.protocolClasses?.filter { $0 != NetworkMonitorURLProtocol.self }
        
        // Create URLSession and start the actual request
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        dataTask = session.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }
    
    /// Stops loading the request
    public override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
        
        // Mark session as cancelled if it exists
        if let sessionId = sessionId {
            let error = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorCancelled,
                userInfo: [NSLocalizedDescriptionKey: "Request was cancelled"]
            )
            NetworkMonitor.shared.failSession(sessionId, with: error)
        }
    }
}

// MARK: - URLSessionDataDelegate

extension NetworkMonitorURLProtocol: URLSessionDataDelegate {
    
    /// Called when a response is received
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        // Forward the response to the client
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        
        // Continue loading
        completionHandler(.allow)
    }
    
    /// Called when data is received
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        
        // Accumulate response data
        responseData.append(data)
        
        // Forward the data to the client
        client?.urlProtocol(self, didLoad: data)
    }
    
    /// Called when the request completes successfully
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        if let error = error {
            // Handle error case
            if let sessionId = sessionId {
                NetworkMonitor.shared.failSession(sessionId, with: error)
            }
            
            // Forward error to client
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            // Handle success case
            if let sessionId = sessionId,
               let httpResponse = task.response as? HTTPURLResponse,
               let startTime = startTime {
                
                let duration = Date().timeIntervalSince(startTime)
                let networkResponse = HTTPResponse.from(httpResponse, data: responseData, duration: duration)
                NetworkMonitor.shared.updateSession(sessionId, with: networkResponse)
            }
            
            // Forward completion to client
            client?.urlProtocolDidFinishLoading(self)
        }
        
        // Clean up
        dataTask = nil
        sessionId = nil
        startTime = nil
        responseData = Data()
    }
    
    /// Called when redirect is encountered
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        
        // Forward redirect to client
        client?.urlProtocol(self, wasRedirectedTo: request, redirectResponse: response)
        
        // Allow the redirect
        completionHandler(request)
    }
    
    /// Called when authentication challenge is encountered
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Use default handling for authentication challenges
        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - Registration Management

public extension NetworkMonitorURLProtocol {
    
    /// Registers the URLProtocol to intercept URLSession requests
    static func register() {
        URLProtocol.registerClass(NetworkMonitorURLProtocol.self)
    }
    
    /// Unregisters the URLProtocol
    static func unregister() {
        URLProtocol.unregisterClass(NetworkMonitorURLProtocol.self)
    }
    
    /// Checks if the URLProtocol is currently registered
    static var isRegistered: Bool {
        let allProtocols = URLSessionConfiguration.default.protocolClasses ?? []
        return allProtocols.contains { $0 == NetworkMonitorURLProtocol.self }
    }
}

// MARK: - NetworkMonitor Integration

internal extension NetworkMonitor {
    
    /// Enables URLProtocol-based automatic interception
    func enableURLProtocolInterception() {
        NetworkMonitorURLProtocol.register()
        logSecurityMessage("🔍 URLProtocol interception enabled")
    }
    
    /// Disables URLProtocol-based automatic interception
    func disableURLProtocolInterception() {
        NetworkMonitorURLProtocol.unregister()
        logSecurityMessage("🔍 URLProtocol interception disabled")
    }
}