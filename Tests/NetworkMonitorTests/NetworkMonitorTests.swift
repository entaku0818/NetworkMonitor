import Testing
@testable import NetworkMonitor

struct NetworkMonitorTests {
    @Test
    func initializationCreatesSharedInstance() {
        // Test that the shared instance exists
        #expect(NetworkMonitor.shared != nil)
    }
    
    @Test
    func monitorStartsAndStopsCorrectly() {
        // Test that the monitor starts and stops correctly
        let monitor = NetworkMonitor.shared
        
        // Test initial state
        #expect(!monitor.isActive())
        
        // Test after starting
        monitor.start()
        #expect(monitor.isActive())
        
        // Test after stopping
        monitor.stop()
        #expect(!monitor.isActive())
    }
    
    @Test
    func versionIsCorrect() {
        // Test that the version string is correct
        #expect(NetworkMonitor.version == "0.1.0")
    }
} 