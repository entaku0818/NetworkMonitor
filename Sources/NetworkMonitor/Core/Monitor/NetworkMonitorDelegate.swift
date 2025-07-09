import Foundation

/// Delegate protocol for receiving NetworkMonitor events
public protocol NetworkMonitorDelegate: AnyObject {
    
    /// Called when a new network session is started
    /// - Parameters:
    ///   - monitor: The NetworkMonitor instance
    ///   - session: The started session
    func networkMonitor(_ monitor: NetworkMonitor, didStartSession session: HTTPSession)
    
    /// Called when a network session is completed successfully
    /// - Parameters:
    ///   - monitor: The NetworkMonitor instance
    ///   - session: The completed session
    func networkMonitor(_ monitor: NetworkMonitor, didCompleteSession session: HTTPSession)
    
    /// Called when a network session fails
    /// - Parameters:
    ///   - monitor: The NetworkMonitor instance
    ///   - session: The failed session
    ///   - error: The error that caused the failure
    func networkMonitor(_ monitor: NetworkMonitor, didFailSession session: HTTPSession, with error: Error)
    
    /// Called when a network session is updated (optional)
    /// - Parameters:
    ///   - monitor: The NetworkMonitor instance
    ///   - session: The updated session
    func networkMonitor(_ monitor: NetworkMonitor, didUpdateSession session: HTTPSession)
    
    /// Called when a network session is cancelled (optional)
    /// - Parameters:
    ///   - monitor: The NetworkMonitor instance
    ///   - session: The cancelled session
    func networkMonitor(_ monitor: NetworkMonitor, didCancelSession session: HTTPSession)
}

// MARK: - Optional Methods

public extension NetworkMonitorDelegate {
    
    /// Default implementation for session updates (optional)
    func networkMonitor(_ monitor: NetworkMonitor, didUpdateSession session: HTTPSession) {
        // Default empty implementation
    }
    
    /// Default implementation for session cancellation (optional)
    func networkMonitor(_ monitor: NetworkMonitor, didCancelSession session: HTTPSession) {
        // Default empty implementation
    }
}

// MARK: - Multi-Delegate Support

/// Manages multiple NetworkMonitor delegates
internal class DelegateManager {
    
    /// Weak reference wrapper for delegates
    private struct WeakDelegate {
        weak var delegate: NetworkMonitorDelegate?
    }
    
    /// Array of weak delegate references
    private var delegates: [WeakDelegate] = []
    
    /// Queue for delegate operations
    private let delegateQueue = DispatchQueue(label: "com.networkmonitor.delegates", qos: .utility)
    
    /// Adds a delegate
    /// - Parameter delegate: The delegate to add
    func addDelegate(_ delegate: NetworkMonitorDelegate) {
        delegateQueue.async {
            // Remove any existing reference to this delegate
            self.removeDelegate(delegate)
            
            // Add the new delegate
            self.delegates.append(WeakDelegate(delegate: delegate))
        }
    }
    
    /// Removes a delegate
    /// - Parameter delegate: The delegate to remove
    func removeDelegate(_ delegate: NetworkMonitorDelegate) {
        delegateQueue.async {
            self.delegates.removeAll { weakDelegate in
                return weakDelegate.delegate === delegate || weakDelegate.delegate == nil
            }
        }
    }
    
    /// Removes all delegates
    func removeAllDelegates() {
        delegateQueue.async {
            self.delegates.removeAll()
        }
    }
    
    /// Notifies all delegates of a session start event
    /// - Parameters:
    ///   - monitor: The NetworkMonitor instance
    ///   - session: The started session
    func notifySessionStarted(_ monitor: NetworkMonitor, session: HTTPSession) {
        notifyDelegates { delegate in
            delegate.networkMonitor(monitor, didStartSession: session)
        }
    }
    
    /// Notifies all delegates of a session completion event
    /// - Parameters:
    ///   - monitor: The NetworkMonitor instance
    ///   - session: The completed session
    func notifySessionCompleted(_ monitor: NetworkMonitor, session: HTTPSession) {
        notifyDelegates { delegate in
            delegate.networkMonitor(monitor, didCompleteSession: session)
        }
    }
    
    /// Notifies all delegates of a session failure event
    /// - Parameters:
    ///   - monitor: The NetworkMonitor instance
    ///   - session: The failed session
    ///   - error: The error that caused the failure
    func notifySessionFailed(_ monitor: NetworkMonitor, session: HTTPSession, error: Error) {
        notifyDelegates { delegate in
            delegate.networkMonitor(monitor, didFailSession: session, with: error)
        }
    }
    
    /// Notifies all delegates of a session update event
    /// - Parameters:
    ///   - monitor: The NetworkMonitor instance
    ///   - session: The updated session
    func notifySessionUpdated(_ monitor: NetworkMonitor, session: HTTPSession) {
        notifyDelegates { delegate in
            delegate.networkMonitor(monitor, didUpdateSession: session)
        }
    }
    
    /// Notifies all delegates of a session cancellation event
    /// - Parameters:
    ///   - monitor: The NetworkMonitor instance
    ///   - session: The cancelled session
    func notifySessionCancelled(_ monitor: NetworkMonitor, session: HTTPSession) {
        notifyDelegates { delegate in
            delegate.networkMonitor(monitor, didCancelSession: session)
        }
    }
    
    /// Helper method to notify all active delegates
    /// - Parameter action: The action to perform on each delegate
    private func notifyDelegates(_ action: @escaping (NetworkMonitorDelegate) -> Void) {
        delegateQueue.async {
            // Clean up nil delegates first
            self.delegates.removeAll { $0.delegate == nil }
            
            // Notify all active delegates on main queue
            let activeDelegates = self.delegates.compactMap { $0.delegate }
            
            DispatchQueue.main.async {
                for delegate in activeDelegates {
                    action(delegate)
                }
            }
        }
    }
    
    /// Returns the number of active delegates
    var delegateCount: Int {
        return delegateQueue.sync {
            delegates.compactMap { $0.delegate }.count
        }
    }
}