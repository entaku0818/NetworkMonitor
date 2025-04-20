import XCTest
@testable import NetworkMonitor

final class NetworkMonitorTests: XCTestCase {
    func testInitializationCreatesSharedInstance() {
        // Test that the shared instance exists
        XCTAssertNotNil(NetworkMonitor.shared)
    }
    
    func testMonitorStartsAndStopsCorrectly() {
        // Test that the monitor starts and stops correctly
        let monitor = NetworkMonitor.shared
        
        // Test initial state
        XCTAssertFalse(monitor.isActive())
        
        // Test after starting
        monitor.start()
        XCTAssertTrue(monitor.isActive())
        
        // Test after stopping
        monitor.stop()
        XCTAssertFalse(monitor.isActive())
    }
    
    func testVersionIsCorrect() {
        // Test that the version string is correct
        XCTAssertEqual(NetworkMonitor.version, "0.1.0")
    }
} 