import Foundation
import NetworkMonitor

/**
 # NetworkMonitor Advanced Usage Examples
 
 This file demonstrates advanced usage patterns and integration scenarios
 for NetworkMonitor in production applications.
 */

// MARK: - Custom Storage Implementation

/// Example: Custom cloud-based storage implementation
class CloudSessionStorage: SessionStorageProtocol {
    private let cloudService: CloudService
    private let queue = DispatchQueue(label: "cloud.storage", qos: .utility)
    
    init(cloudService: CloudService) {
        self.cloudService = cloudService
    }
    
    func save(session: HTTPSession, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            // Convert session to uploadable format
            do {
                let data = try JSONEncoder().encode(session)
                self.cloudService.upload(data: data, key: session.id.uuidString) { success in
                    DispatchQueue.main.async {
                        completion(success ? .success(()) : .failure(StorageError.uploadFailed))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func save(sessions: [HTTPSession], completion: @escaping (Result<Void, Error>) -> Void) {
        // Implement batch upload
        let group = DispatchGroup()
        var errors: [Error] = []
        
        for session in sessions {
            group.enter()
            save(session: session) { result in
                if case .failure(let error) = result {
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(errors.isEmpty ? .success(()) : .failure(errors.first!))
        }
    }
    
    func load(sessionID: UUID, completion: @escaping (Result<HTTPSession?, Error>) -> Void) {
        queue.async {
            self.cloudService.download(key: sessionID.uuidString) { data in
                DispatchQueue.main.async {
                    guard let data = data else {
                        completion(.success(nil))
                        return
                    }
                    
                    do {
                        let session = try JSONDecoder().decode(HTTPSession.self, from: data)
                        completion(.success(session))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    func loadAll(completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
        queue.async {
            self.cloudService.listAll { keys in
                var sessions: [HTTPSession] = []
                let group = DispatchGroup()
                
                for key in keys {
                    group.enter()
                    if let uuid = UUID(uuidString: key) {
                        self.load(sessionID: uuid) { result in
                            if case .success(let session) = result, let session = session {
                                sessions.append(session)
                            }
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    completion(.success(sessions))
                }
            }
        }
    }
    
    func load(matching criteria: FilterCriteriaProtocol, completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
        loadAll { result in
            switch result {
            case .success(let sessions):
                let filtered = sessions.filter { criteria.matches(session: $0) }
                completion(.success(filtered))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func delete(sessionID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            self.cloudService.delete(key: sessionID.uuidString) { success in
                DispatchQueue.main.async {
                    completion(success ? .success(()) : .failure(StorageError.deleteFailed))
                }
            }
        }
    }
    
    func deleteAll(completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            self.cloudService.deleteAll { success in
                DispatchQueue.main.async {
                    completion(success ? .success(()) : .failure(StorageError.deleteFailed))
                }
            }
        }
    }
    
    func delete(matching criteria: FilterCriteriaProtocol, completion: @escaping (Result<Int, Error>) -> Void) {
        load(matching: criteria) { result in
            switch result {
            case .success(let sessions):
                var deletedCount = 0
                let group = DispatchGroup()
                
                for session in sessions {
                    group.enter()
                    self.delete(sessionID: session.id) { deleteResult in
                        if case .success = deleteResult {
                            deletedCount += 1
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    completion(.success(deletedCount))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func count(completion: @escaping (Result<Int, Error>) -> Void) {
        loadAll { result in
            switch result {
            case .success(let sessions):
                completion(.success(sessions.count))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func storageSize(completion: @escaping (Result<Int64, Error>) -> Void) {
        queue.async {
            self.cloudService.getStorageSize { size in
                DispatchQueue.main.async {
                    completion(.success(size))
                }
            }
        }
    }
    
    enum StorageError: Error {
        case uploadFailed
        case deleteFailed
    }
}

// MARK: - Custom Filter Implementation

/// Example: Business logic filter for API rate limiting analysis
struct RateLimitAnalysisFilter: FilterCriteriaProtocol {
    let timeWindow: TimeInterval
    let maxRequestsPerWindow: Int
    let hostPattern: String
    
    func matches(session: HTTPSession) -> Bool {
        // This would typically be implemented with access to all sessions
        // to count requests within the time window
        
        // Basic implementation - check if it's an API host
        guard let url = URL(string: session.request.url),
              let host = url.host else { return false }
        
        return host.contains(hostPattern)
    }
}

/// Example: Security-focused filter for detecting potential attacks
struct SecurityAnomalyFilter: FilterCriteriaProtocol {
    func matches(session: HTTPSession) -> Bool {
        // Check for common attack patterns
        let url = session.request.url.lowercased()
        
        // SQL injection patterns
        let sqlPatterns = ["union select", "drop table", "'; --", "' or '1'='1"]
        for pattern in sqlPatterns {
            if url.contains(pattern) {
                return true
            }
        }
        
        // XSS patterns
        let xssPatterns = ["<script>", "javascript:", "onerror="]
        for pattern in xssPatterns {
            if url.contains(pattern) {
                return true
            }
        }
        
        // Path traversal patterns
        let pathTraversalPatterns = ["../", "..\\", "%2e%2e"]
        for pattern in pathTraversalPatterns {
            if url.contains(pattern) {
                return true
            }
        }
        
        // Large number of failed authentication attempts
        if session.statusCode == 401 && url.contains("login") {
            return true
        }
        
        return false
    }
}

// MARK: - Real-time Monitoring System

/// Example: Real-time network monitoring with alerts
class RealTimeNetworkMonitor {
    private let storage: SessionStorageProtocol
    private let alertThresholds: AlertThresholds
    private var observers: [NetworkObserver] = []
    
    struct AlertThresholds {
        let maxErrorRate: Double = 0.1 // 10% error rate
        let maxResponseTime: TimeInterval = 3.0 // 3 seconds
        let minSuccessRate: Double = 0.9 // 90% success rate
        let rateLimitWindow: TimeInterval = 60.0 // 1 minute
        let maxRequestsPerWindow: Int = 1000
    }
    
    init(storage: SessionStorageProtocol, thresholds: AlertThresholds = AlertThresholds()) {
        self.storage = storage
        self.alertThresholds = thresholds
    }
    
    func addObserver(_ observer: NetworkObserver) {
        observers.append(observer)
    }
    
    func removeObserver(_ observer: NetworkObserver) {
        observers.removeAll { $0 === observer }
    }
    
    func processSession(_ session: HTTPSession) {
        // Save session
        storage.save(session: session) { result in
            switch result {
            case .success():
                self.analyzeForAlerts(session)
            case .failure(let error):
                self.notifyObservers(.storageError(error))
            }
        }
    }
    
    private func analyzeForAlerts(_ session: HTTPSession) {
        // Check for slow response
        if session.duration > alertThresholds.maxResponseTime {
            notifyObservers(.slowResponse(session))
        }
        
        // Check for errors
        if session.isFailed {
            notifyObservers(.errorResponse(session))
            
            // Check error rate over recent period
            checkErrorRate()
        }
        
        // Check for security anomalies
        let securityFilter = SecurityAnomalyFilter()
        if securityFilter.matches(session: session) {
            notifyObservers(.securityAnomaly(session))
        }
        
        // Check for rate limiting
        checkRateLimit(for: session)
    }
    
    private func checkErrorRate() {
        let recentTimeFrame = Date().addingTimeInterval(-300) // Last 5 minutes
        let recentFilter = FilterCriteria().timestamp(from: recentTimeFrame, to: nil)
        
        storage.load(matching: recentFilter) { result in
            switch result {
            case .success(let recentSessions):
                guard !recentSessions.isEmpty else { return }
                
                let errorCount = recentSessions.filter { $0.isFailed }.count
                let errorRate = Double(errorCount) / Double(recentSessions.count)
                
                if errorRate > self.alertThresholds.maxErrorRate {
                    self.notifyObservers(.highErrorRate(errorRate, recentSessions.count))
                }
                
            case .failure(let error):
                self.notifyObservers(.storageError(error))
            }
        }
    }
    
    private func checkRateLimit(for session: HTTPSession) {
        guard let url = URL(string: session.request.url),
              let host = url.host else { return }
        
        let windowStart = Date().addingTimeInterval(-alertThresholds.rateLimitWindow)
        let hostFilter = FilterCriteria()
            .host(pattern: host)
            .timestamp(from: windowStart, to: nil)
        
        storage.load(matching: hostFilter) { result in
            switch result {
            case .success(let hostSessions):
                if hostSessions.count > self.alertThresholds.maxRequestsPerWindow {
                    self.notifyObservers(.rateLimitExceeded(host, hostSessions.count))
                }
                
            case .failure(let error):
                self.notifyObservers(.storageError(error))
            }
        }
    }
    
    private func notifyObservers(_ alert: NetworkAlert) {
        for observer in observers {
            observer.didReceiveAlert(alert)
        }
    }
    
    enum NetworkAlert {
        case slowResponse(HTTPSession)
        case errorResponse(HTTPSession)
        case highErrorRate(Double, Int)
        case securityAnomaly(HTTPSession)
        case rateLimitExceeded(String, Int)
        case storageError(Error)
    }
}

// MARK: - Protocol Definitions

protocol NetworkObserver: AnyObject {
    func didReceiveAlert(_ alert: RealTimeNetworkMonitor.NetworkAlert)
}

protocol CloudService {
    func upload(data: Data, key: String, completion: @escaping (Bool) -> Void)
    func download(key: String, completion: @escaping (Data?) -> Void)
    func delete(key: String, completion: @escaping (Bool) -> Void)
    func deleteAll(completion: @escaping (Bool) -> Void)
    func listAll(completion: @escaping ([String]) -> Void)
    func getStorageSize(completion: @escaping (Int64) -> Void)
}

// MARK: - Network Analytics Engine

/// Example: Advanced analytics for network performance
class NetworkAnalyticsEngine {
    private let storage: SessionStorageProtocol
    private let filterEngine: FilterEngine
    
    init(storage: SessionStorageProtocol) {
        self.storage = storage
        self.filterEngine = FilterEngine()
        self.filterEngine.isPerformanceTrackingEnabled = true
    }
    
    struct AnalyticsReport {
        let totalSessions: Int
        let averageResponseTime: TimeInterval
        let errorRate: Double
        let topHosts: [(host: String, count: Int)]
        let slowestEndpoints: [(url: String, avgDuration: TimeInterval)]
        let errorDistribution: [Int: Int] // [statusCode: count]
        let hourlyDistribution: [Int: Int] // [hour: count]
        let methodDistribution: [String: Int] // [method: count]
        let contentTypeDistribution: [String: Int] // [contentType: count]
    }
    
    func generateReport(for dateRange: DateRange, completion: @escaping (Result<AnalyticsReport, Error>) -> Void) {
        let dateFilter = FilterCriteria().timestamp(from: dateRange.start, to: dateRange.end)
        
        storage.load(matching: dateFilter) { result in
            switch result {
            case .success(let sessions):
                let report = self.analyzeSessions(sessions)
                completion(.success(report))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func analyzeSessions(_ sessions: [HTTPSession]) -> AnalyticsReport {
        let completedSessions = sessions.filter { $0.isCompleted }
        
        // Basic metrics
        let totalSessions = sessions.count
        let avgResponseTime = completedSessions.compactMap { $0.response?.duration }.reduce(0, +) / Double(max(completedSessions.count, 1))
        let errorCount = sessions.filter { $0.isFailed }.count
        let errorRate = Double(errorCount) / Double(max(totalSessions, 1))
        
        // Host analysis
        let hostCounts = Dictionary(grouping: sessions.compactMap { $0.host }, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { (host: $0.key, count: $0.value) }
        
        // Slowest endpoints
        let endpointDurations = Dictionary(grouping: completedSessions, by: { $0.request.url })
            .mapValues { sessions in
                sessions.compactMap { $0.response?.duration }.reduce(0, +) / Double(sessions.count)
            }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { (url: $0.key, avgDuration: $0.value) }
        
        // Error distribution
        let errorDistribution = Dictionary(grouping: sessions.compactMap { $0.statusCode }, by: { $0 })
            .mapValues { $0.count }
        
        // Hourly distribution
        let calendar = Calendar.current
        let hourlyDistribution = Dictionary(grouping: sessions, by: { calendar.component(.hour, from: $0.startTime) })
            .mapValues { $0.count }
        
        // Method distribution
        let methodDistribution = Dictionary(grouping: sessions, by: { $0.httpMethod })
            .mapValues { $0.count }
        
        // Content type distribution
        let contentTypes = sessions.compactMap { session in
            session.response?.headers["Content-Type"] ?? session.request.headers["Content-Type"]
        }
        let contentTypeDistribution = Dictionary(grouping: contentTypes, by: { $0 })
            .mapValues { $0.count }
        
        return AnalyticsReport(
            totalSessions: totalSessions,
            averageResponseTime: avgResponseTime,
            errorRate: errorRate,
            topHosts: Array(hostCounts),
            slowestEndpoints: Array(endpointDurations),
            errorDistribution: errorDistribution,
            hourlyDistribution: hourlyDistribution,
            methodDistribution: methodDistribution,
            contentTypeDistribution: contentTypeDistribution
        )
    }
    
    func exportReport(_ report: AnalyticsReport, format: ExportFormat) -> String {
        switch format {
        case .json:
            return exportAsJSON(report)
        case .csv:
            return exportAsCSV(report)
        case .html:
            return exportAsHTML(report)
        }
    }
    
    private func exportAsJSON(_ report: AnalyticsReport) -> String {
        // Convert report to JSON format
        let jsonData: [String: Any] = [
            "totalSessions": report.totalSessions,
            "averageResponseTime": report.averageResponseTime,
            "errorRate": report.errorRate,
            "topHosts": report.topHosts.map { ["host": $0.host, "count": $0.count] },
            "slowestEndpoints": report.slowestEndpoints.map { ["url": $0.url, "duration": $0.avgDuration] },
            "errorDistribution": report.errorDistribution,
            "hourlyDistribution": report.hourlyDistribution,
            "methodDistribution": report.methodDistribution,
            "contentTypeDistribution": report.contentTypeDistribution
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: jsonData, options: .prettyPrinted)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to generate JSON\"}"
        }
    }
    
    private func exportAsCSV(_ report: AnalyticsReport) -> String {
        var csv = "Metric,Value\n"
        csv += "Total Sessions,\(report.totalSessions)\n"
        csv += "Average Response Time,\(String(format: "%.3f", report.averageResponseTime))\n"
        csv += "Error Rate,\(String(format: "%.2f", report.errorRate * 100))%\n\n"
        
        csv += "Top Hosts\n"
        csv += "Host,Count\n"
        for host in report.topHosts {
            csv += "\(host.host),\(host.count)\n"
        }
        
        return csv
    }
    
    private func exportAsHTML(_ report: AnalyticsReport) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Network Analytics Report</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .metric { margin: 10px 0; }
                .value { font-weight: bold; color: #2196F3; }
                table { border-collapse: collapse; width: 100%; margin: 20px 0; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; }
            </style>
        </head>
        <body>
            <h1>Network Analytics Report</h1>
            
            <div class="metric">Total Sessions: <span class="value">\(report.totalSessions)</span></div>
            <div class="metric">Average Response Time: <span class="value">\(String(format: "%.3f", report.averageResponseTime))s</span></div>
            <div class="metric">Error Rate: <span class="value">\(String(format: "%.2f", report.errorRate * 100))%</span></div>
            
            <h2>Top Hosts</h2>
            <table>
                <tr><th>Host</th><th>Request Count</th></tr>
                \(report.topHosts.map { "<tr><td>\($0.host)</td><td>\($0.count)</td></tr>" }.joined(separator: ""))
            </table>
            
            <h2>Slowest Endpoints</h2>
            <table>
                <tr><th>URL</th><th>Average Duration</th></tr>
                \(report.slowestEndpoints.map { "<tr><td>\($0.url)</td><td>\(String(format: "%.3f", $0.avgDuration))s</td></tr>" }.joined(separator: ""))
            </table>
        </body>
        </html>
        """
    }
    
    enum ExportFormat {
        case json
        case csv
        case html
    }
}

// MARK: - Usage Examples

/// Example usage of advanced features
class AdvancedUsageExamples {
    
    static func demoRealTimeMonitoring() {
        let monitor = RealTimeNetworkMonitor(storage: NetworkMonitorAPI.defaultStorage)
        
        // Add alert observer
        let alertHandler = AlertHandler()
        monitor.addObserver(alertHandler)
        
        // Simulate processing sessions
        let request = HTTPRequest(url: "https://api.example.com/users", method: .get)
        let response = HTTPResponse(statusCode: 500, duration: 5.0) // Slow error response
        let session = HTTPSession(request: request, response: response, state: .completed)
        
        monitor.processSession(session)
    }
    
    static func demoAnalytics() {
        let analytics = NetworkAnalyticsEngine(storage: NetworkMonitorAPI.defaultStorage)
        
        analytics.generateReport(for: .lastWeek) { result in
            switch result {
            case .success(let report):
                print("📊 Analytics Report:")
                print("   Total Sessions: \(report.totalSessions)")
                print("   Avg Response Time: \(String(format: "%.3f", report.averageResponseTime))s")
                print("   Error Rate: \(String(format: "%.2f", report.errorRate * 100))%")
                
                // Export as HTML
                let html = analytics.exportReport(report, format: .html)
                print("   HTML Report Generated: \(html.count) characters")
                
            case .failure(let error):
                print("❌ Analytics failed: \(error)")
            }
        }
    }
    
    static func demoSecurityFiltering() {
        let securityFilter = SecurityAnomalyFilter()
        let storage = NetworkMonitorAPI.defaultStorage
        
        storage.load(matching: securityFilter) { result in
            switch result {
            case .success(let suspiciousSessions):
                print("🚨 Found \(suspiciousSessions.count) potentially malicious requests")
                
                for session in suspiciousSessions {
                    print("   ⚠️  \(session.request.url)")
                }
                
            case .failure(let error):
                print("❌ Security analysis failed: \(error)")
            }
        }
    }
}

// MARK: - Alert Handler Implementation

class AlertHandler: NetworkObserver {
    func didReceiveAlert(_ alert: RealTimeNetworkMonitor.NetworkAlert) {
        switch alert {
        case .slowResponse(let session):
            print("🐌 SLOW RESPONSE: \(session.url) took \(String(format: "%.2f", session.duration))s")
            
        case .errorResponse(let session):
            print("❌ ERROR RESPONSE: \(session.statusCode ?? 0) from \(session.url)")
            
        case .highErrorRate(let rate, let count):
            print("🚨 HIGH ERROR RATE: \(String(format: "%.1f", rate * 100))% over \(count) requests")
            
        case .securityAnomaly(let session):
            print("🔒 SECURITY ALERT: Suspicious request to \(session.url)")
            
        case .rateLimitExceeded(let host, let count):
            print("⚡ RATE LIMIT: \(host) exceeded limit with \(count) requests")
            
        case .storageError(let error):
            print("💾 STORAGE ERROR: \(error.localizedDescription)")
        }
    }
}