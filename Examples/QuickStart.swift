import Foundation
import NetworkMonitor

/**
 # NetworkMonitor Quick Start Guide
 
 This file contains the minimal code needed to get started with NetworkMonitor.
 Perfect for copying into your project for immediate use.
 */

// MARK: - Minimal Setup (Copy this to get started!)

class NetworkMonitorQuickStart {
    
    /// Step 1: Start monitoring (call this in your app startup)
    static func startMonitoring() {
        // Quick and safe way to start monitoring
        let result = NetworkMonitorAPI.quickStart()
        
        switch result {
        case .success():
            print("✅ NetworkMonitor started")
        case .failure(let error):
            print("❌ Failed to start: \(error.localizedDescription)")
        }
    }
    
    /// Step 2: Save network sessions (integrate this with your networking code)
    static func saveNetworkSession(url: String, method: HTTPRequest.Method, statusCode: Int, duration: TimeInterval) {
        // Create request
        let request = HTTPRequest(url: url, method: method)
        
        // Create response
        let response = HTTPResponse(statusCode: statusCode, duration: duration)
        
        // Create session
        let session = HTTPSession(request: request, response: response, state: .completed)
        
        // Save to storage
        NetworkMonitorAPI.defaultStorage.save(session: session) { result in
            switch result {
            case .success():
                print("📝 Saved: \(method.rawValue) \(url)")
            case .failure(let error):
                print("❌ Save failed: \(error)")
            }
        }
    }
    
    /// Step 3: Search your network activity
    static func searchNetworkActivity(searchText: String) {
        // Load all sessions
        NetworkMonitorAPI.defaultStorage.loadAll { result in
            switch result {
            case .success(let sessions):
                // Quick search
                NetworkMonitorAPI.quickSearch(text: searchText, in: sessions) { searchResult in
                    switch searchResult {
                    case .success(let matchingSessions):
                        print("🔍 Found \(matchingSessions.count) matches for '\(searchText)'")
                        
                        // Print first few results
                        for session in matchingSessions.prefix(5) {
                            print("  📱 \(session.httpMethod) \(session.url)")
                        }
                        
                    case .failure(let error):
                        print("❌ Search failed: \(error)")
                    }
                }
                
            case .failure(let error):
                print("❌ Failed to load sessions: \(error)")
            }
        }
    }
    
    /// Step 4: Filter network activity
    static func filterNetworkActivity() {
        // Filter for errors only
        let errorFilter = NetworkMonitorAPI.errorRequestsOnly()
        
        NetworkMonitorAPI.defaultStorage.load(matching: errorFilter) { result in
            switch result {
            case .success(let errorSessions):
                print("🚨 Found \(errorSessions.count) error requests")
                
                for session in errorSessions {
                    print("  ❌ \(session.statusCode ?? 0) - \(session.url)")
                }
                
            case .failure(let error):
                print("❌ Filter failed: \(error)")
            }
        }
        
        // Filter for slow requests
        let slowFilter = FilterCriteria().duration(min: 2.0, max: 60.0)
        
        NetworkMonitorAPI.defaultStorage.load(matching: slowFilter) { result in
            switch result {
            case .success(let slowSessions):
                print("🐌 Found \(slowSessions.count) slow requests")
                
            case .failure(let error):
                print("❌ Slow filter failed: \(error)")
            }
        }
    }
    
    /// Step 5: Get monitoring statistics
    static func getStatistics() {
        // Session count
        NetworkMonitorAPI.getSessionCount { result in
            switch result {
            case .success(let count):
                print("📊 Total sessions: \(count)")
            case .failure(let error):
                print("❌ Count failed: \(error)")
            }
        }
        
        // Memory usage
        let memoryStats = NetworkMonitorAPI.getMemoryStatistics()
        print("💾 Memory: \(memoryStats.humanReadableMemoryUsage)")
        print("📈 Usage: \(String(format: "%.1f", memoryStats.sessionCountRatio * 100))%")
    }
    
    /// Step 6: Stop monitoring (call this when your app closes)
    static func stopMonitoring() {
        NetworkMonitorAPI.quickStop()
        print("🛑 NetworkMonitor stopped")
    }
}

// MARK: - Integration Examples

/**
 Integration with URLSession:
 
 ```swift
 // In your networking class:
 extension URLSession {
     func dataTaskWithMonitoring(with url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
         let startTime = Date()
         
         return dataTask(with: url) { data, response, error in
             let endTime = Date()
             let duration = endTime.timeIntervalSince(startTime)
             
             // Log to NetworkMonitor
             if let httpResponse = response as? HTTPURLResponse {
                 NetworkMonitorQuickStart.saveNetworkSession(
                     url: url.absoluteString,
                     method: .get,
                     statusCode: httpResponse.statusCode,
                     duration: duration
                 )
             }
             
             completion(data, response, error)
         }
     }
 }
 ```
 */

/**
 Integration with Alamofire:
 
 ```swift
 // Using Alamofire EventMonitor:
 class NetworkMonitorEventMonitor: EventMonitor {
     func request<Value>(_ request: DataRequest, didCompleteTask task: URLSessionTask, with result: Result<Value, AFError>) {
         guard let httpResponse = task.response as? HTTPURLResponse,
               let url = task.originalRequest?.url else { return }
         
         let duration = task.taskInterval?.duration ?? 0
         let method = HTTPRequest.Method(rawValue: task.originalRequest?.httpMethod ?? "GET") ?? .get
         
         NetworkMonitorQuickStart.saveNetworkSession(
             url: url.absoluteString,
             method: method,
             statusCode: httpResponse.statusCode,
             duration: duration
         )
     }
 }
 
 // Add to your SessionManager:
 let session = Session(eventMonitors: [NetworkMonitorEventMonitor()])
 ```
 */

// MARK: - SwiftUI Integration Example

/**
 SwiftUI App Integration:
 
 ```swift
 @main
 struct MyApp: App {
     init() {
         // Start monitoring when app launches
         NetworkMonitorQuickStart.startMonitoring()
     }
     
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                     // Stop monitoring when app terminates
                     NetworkMonitorQuickStart.stopMonitoring()
                 }
         }
     }
 }
 
 // In your views:
 struct NetworkDebugView: View {
     @State private var sessionCount = 0
     @State private var searchText = ""
     @State private var searchResults: [HTTPSession] = []
     
     var body: some View {
         VStack {
             Text("Network Sessions: \(sessionCount)")
             
             TextField("Search...", text: $searchText)
                 .onSubmit {
                     NetworkMonitorQuickStart.searchNetworkActivity(searchText: searchText)
                 }
             
             Button("Show Error Requests") {
                 NetworkMonitorQuickStart.filterNetworkActivity()
             }
             
             Button("Refresh Stats") {
                 NetworkMonitorQuickStart.getStatistics()
             }
         }
         .onAppear {
             NetworkMonitorQuickStart.getStatistics()
         }
     }
 }
 ```
 */

// MARK: - UIKit Integration Example

/**
 UIKit App Integration:
 
 ```swift
 // In AppDelegate:
 func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     NetworkMonitorQuickStart.startMonitoring()
     return true
 }
 
 func applicationWillTerminate(_ application: UIApplication) {
     NetworkMonitorQuickStart.stopMonitoring()
 }
 
 // In your ViewControllers:
 class NetworkDebugViewController: UIViewController {
     @IBOutlet weak var sessionCountLabel: UILabel!
     @IBOutlet weak var searchTextField: UITextField!
     
     override func viewDidLoad() {
         super.viewDidLoad()
         refreshStats()
     }
     
     @IBAction func searchButtonTapped(_ sender: UIButton) {
         guard let searchText = searchTextField.text, !searchText.isEmpty else { return }
         NetworkMonitorQuickStart.searchNetworkActivity(searchText: searchText)
     }
     
     @IBAction func showErrorsButtonTapped(_ sender: UIButton) {
         NetworkMonitorQuickStart.filterNetworkActivity()
     }
     
     private func refreshStats() {
         NetworkMonitorAPI.getSessionCount { result in
             DispatchQueue.main.async {
                 switch result {
                 case .success(let count):
                     self.sessionCountLabel.text = "Sessions: \(count)"
                 case .failure:
                     self.sessionCountLabel.text = "Sessions: Error"
                 }
             }
         }
     }
 }
 ```
 */

// MARK: - Testing Integration

/**
 Unit Testing with NetworkMonitor:
 
 ```swift
 class NetworkMonitorTests: XCTestCase {
     override func setUp() {
         super.setUp()
         NetworkMonitorQuickStart.startMonitoring()
     }
     
     override func tearDown() {
         // Clear test data
         NetworkMonitorAPI.clearAllSessions { _ in }
         NetworkMonitorQuickStart.stopMonitoring()
         super.tearDown()
     }
     
     func testNetworkLogging() {
         let expectation = XCTestExpectation(description: "Network session saved")
         
         // Simulate a network request
         NetworkMonitorQuickStart.saveNetworkSession(
             url: "https://api.test.com/users",
             method: .get,
             statusCode: 200,
             duration: 0.5
         )
         
         // Wait a bit for async save
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
             NetworkMonitorAPI.getSessionCount { result in
                 switch result {
                 case .success(let count):
                     XCTAssertGreaterThan(count, 0)
                     expectation.fulfill()
                 case .failure:
                     XCTFail("Failed to get session count")
                 }
             }
         }
         
         wait(for: [expectation], timeout: 1.0)
     }
 }
 ```
 */