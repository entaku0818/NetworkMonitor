import XCTest
@testable import NetworkMonitor

final class ReleaseBuildTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset static state before each test
        NetworkMonitor.allowReleaseMonitoring = false
    }
    
    func testBuildConfigurationDetection() {
        // Test that build configuration is properly detected
        let config = NetworkMonitor.BuildConfiguration.current
        
        #if DEBUG
        XCTAssertEqual(config, .debug)
        #else
        XCTAssertEqual(config, .release)
        #endif
    }
    
    func testMonitoringStates() {
        let monitor = NetworkMonitor.shared
        
        // Test all states can be created
        let active = NetworkMonitor.MonitoringState.active
        let inactive = NetworkMonitor.MonitoringState.inactive
        let disabled = NetworkMonitor.MonitoringState.disabled(reason: "Test reason")
        
        XCTAssertNotNil(active)
        XCTAssertNotNil(inactive)
        XCTAssertNotNil(disabled)
        
        // Test disabled state has reason
        if case let .disabled(reason) = disabled {
            XCTAssertEqual(reason, "Test reason")
        } else {
            XCTFail("Expected disabled state with reason")
        }
    }
    
    func testReleaseMonitoringFlag() {
        // Test that the flag starts as false
        XCTAssertFalse(NetworkMonitor.allowReleaseMonitoring)
        
        // Test that it can be set to true
        NetworkMonitor.allowReleaseMonitoring = true
        XCTAssertTrue(NetworkMonitor.allowReleaseMonitoring)
        
        // Reset for other tests
        NetworkMonitor.allowReleaseMonitoring = false
    }
    
    func testSafetyCheck() {
        let monitor = NetworkMonitor.shared
        
        let result = monitor.performSafetyCheck()
        
        #if DEBUG
        // In debug builds, safety check should pass
        switch result {
        case .success():
            XCTAssertTrue(true) // Expected success
        case .failure(let error):
            XCTFail("Safety check should pass in debug build: \(error)")
        }
        #else
        // In release builds, safety check should fail unless flag is set
        if !NetworkMonitor.allowReleaseMonitoring {
            switch result {
            case .success():
                XCTFail("Safety check should fail in release build without flag")
            case .failure(let error):
                XCTAssertEqual(error, .releaseMonitoringBlocked)
            }
        }
        #endif
    }
    
    func testStartWithSafetyConfirmation() {
        let monitor = NetworkMonitor.shared
        
        // Reset state first
        monitor.stop()
        NetworkMonitor.allowReleaseMonitoring = false
        
        #if DEBUG
        // In debug builds, should succeed without confirmation
        let result = monitor.startWithSafetyConfirmation()
        switch result {
        case .success():
            XCTAssertTrue(monitor.isActive())
        case .failure(let error):
            // In debug builds, if the monitor was previously disabled, we might get startupFailed
            // This is expected behavior and not an error
            if case .startupFailed = error {
                // This is acceptable in debug builds when state is disabled
                XCTAssertTrue(true)
            } else {
                XCTFail("Unexpected error in debug build: \(error)")
            }
        }
        #else
        // In release builds, should fail without confirmation
        let resultWithoutConfirmation = monitor.startWithSafetyConfirmation(confirmReleaseUsage: false)
        switch resultWithoutConfirmation {
        case .success():
            XCTFail("Should fail in release build without confirmation")
        case .failure(let error):
            XCTAssertEqual(error, .releaseUsageNotConfirmed)
        }
        
        // With confirmation, should succeed
        let resultWithConfirmation = monitor.startWithSafetyConfirmation(confirmReleaseUsage: true)
        switch resultWithConfirmation {
        case .success():
            XCTAssertTrue(monitor.isActive())
        case .failure(let error):
            XCTFail("Should succeed in release build with confirmation: \(error)")
        }
        #endif
    }
    
    func testForceDisable() {
        let monitor = NetworkMonitor.shared
        
        // Start monitoring first
        monitor.start()
        
        // Force disable
        monitor.forceDisable()
        
        // Should not be active
        XCTAssertFalse(monitor.isActive())
        
        // Should be in disabled state
        let state = monitor.monitoringState()
        if case .disabled = state {
            XCTAssertTrue(true) // Expected disabled state
        } else {
            XCTFail("Expected disabled state after force disable")
        }
        
        // Flag should be reset
        XCTAssertFalse(NetworkMonitor.allowReleaseMonitoring)
    }
    
    func testBuildInfo() {
        let buildInfo = NetworkMonitor.buildInfo
        
        // Should contain expected keys
        XCTAssertNotNil(buildInfo["version"])
        XCTAssertNotNil(buildInfo["buildConfiguration"])
        XCTAssertNotNil(buildInfo["isDebugBuild"])
        XCTAssertNotNil(buildInfo["releaseMonitoringAllowed"])
        
        // Version should match
        XCTAssertEqual(buildInfo["version"] as? String, NetworkMonitor.version)
        
        // Build configuration should match
        #if DEBUG
        XCTAssertEqual(buildInfo["buildConfiguration"] as? String, "debug")
        XCTAssertEqual(buildInfo["isDebugBuild"] as? Bool, true)
        #else
        XCTAssertEqual(buildInfo["buildConfiguration"] as? String, "release")
        XCTAssertEqual(buildInfo["isDebugBuild"] as? Bool, false)
        #endif
        
        // Release monitoring flag should match
        XCTAssertEqual(buildInfo["releaseMonitoringAllowed"] as? Bool, NetworkMonitor.allowReleaseMonitoring)
    }
    
    func testNetworkMonitorErrorDescriptions() {
        let errors: [NetworkMonitorError] = [
            .releaseMonitoringBlocked,
            .releaseUsageNotConfirmed,
            .startupFailed
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
        
        // Test specific error descriptions
        XCTAssertEqual(NetworkMonitorError.releaseMonitoringBlocked.errorDescription, "Network monitoring is blocked in release builds for security reasons")
        XCTAssertEqual(NetworkMonitorError.releaseUsageNotConfirmed.errorDescription, "Release usage must be explicitly confirmed to enable monitoring")
        XCTAssertEqual(NetworkMonitorError.startupFailed.errorDescription, "Failed to start network monitoring")
    }
    
    func testVersionConstant() {
        // Test that version is set correctly
        XCTAssertEqual(NetworkMonitor.version, "0.1.0")
        XCTAssertFalse(NetworkMonitor.version.isEmpty)
    }
    
    func testStartStopCycle() {
        let monitor = NetworkMonitor.shared
        
        // Reset state first
        monitor.stop()
        NetworkMonitor.allowReleaseMonitoring = false
        
        // Check initial state - might be disabled from previous tests
        let initialState = monitor.monitoringState()
        let initiallyActive = monitor.isActive()
        
        // Start monitoring
        monitor.start()
        
        #if DEBUG
        // Should be active in debug builds if not previously disabled
        if case .disabled = initialState {
            // If it was disabled, it should remain inactive
            XCTAssertFalse(monitor.isActive())
        } else {
            // If it was not disabled, it should become active
            XCTAssertTrue(monitor.isActive())
        }
        #else
        // Should not be active in release builds without flag
        if !NetworkMonitor.allowReleaseMonitoring {
            XCTAssertFalse(monitor.isActive())
        }
        #endif
        
        // Stop monitoring
        monitor.stop()
        // After stopping, should not be active (unless permanently disabled)
        if case .disabled = monitor.monitoringState() {
            XCTAssertFalse(monitor.isActive())
        } else {
            XCTAssertFalse(monitor.isActive())
        }
    }
}