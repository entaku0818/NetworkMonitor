import Foundation

/// Manages HTTP sessions and their lifecycle
internal class SessionManager {
    
    // MARK: - Properties
    
    /// Storage provider for sessions
    private let storage: SessionStorageProtocol
    
    /// Currently tracked sessions
    private var trackedSessions: [UUID: HTTPSession] = [:]
    
    /// Queue for managing session operations
    private let sessionQueue = DispatchQueue(label: "com.networkmonitor.sessionmanager", qos: .utility)
    
    /// Whether the session manager is currently active
    private var isActive: Bool = false
    
    /// Session observers
    private var observers: [SessionObserver] = []
    
    // MARK: - Initialization
    
    init(storage: SessionStorageProtocol) {
        self.storage = storage
    }
    
    // MARK: - Lifecycle Methods
    
    /// Starts the session manager
    func start() {
        sessionQueue.async {
            self.isActive = true
            self.trackedSessions.removeAll()
        }
    }
    
    /// Stops the session manager
    func stop() {
        sessionQueue.async {
            self.isActive = false
            
            // Complete any remaining tracked sessions
            for (_, session) in self.trackedSessions {
                let completedSession = session.completed(
                    response: HTTPResponse(statusCode: 0, body: nil, duration: 0.0),
                    endTime: Date()
                )
                
                self.storage.save(session: completedSession) { _ in }
                self.notifyObservers { observer in
                    observer.sessionCompleted(completedSession)
                }
            }
            
            self.trackedSessions.removeAll()
        }
    }
    
    // MARK: - Session Management
    
    /// Adds a new session for tracking
    /// - Parameter session: The session to add
    func addSession(_ session: HTTPSession) {
        sessionQueue.async {
            guard self.isActive else { return }
            
            self.trackedSessions[session.id] = session
            
            // Notify observers
            self.notifyObservers { observer in
                observer.sessionStarted(session)
            }
        }
    }
    
    /// Updates an existing session
    /// - Parameter session: The updated session
    func updateSession(_ session: HTTPSession) {
        sessionQueue.async {
            guard self.isActive else { return }
            
            self.trackedSessions[session.id] = session
            
            // Notify observers
            self.notifyObservers { observer in
                observer.sessionUpdated(session)
            }
        }
    }
    
    /// Removes a session from tracking
    /// - Parameter sessionId: The ID of the session to remove
    func removeSession(_ sessionId: UUID) {
        sessionQueue.async {
            guard self.isActive else { return }
            
            if let session = self.trackedSessions.removeValue(forKey: sessionId) {
                // Notify observers
                self.notifyObservers { observer in
                    observer.sessionRemoved(session)
                }
            }
        }
    }
    
    /// Gets a tracked session by ID
    /// - Parameter sessionId: The session ID
    /// - Returns: The session if found
    func getSession(_ sessionId: UUID) -> HTTPSession? {
        return sessionQueue.sync {
            return trackedSessions[sessionId]
        }
    }
    
    /// Gets all currently tracked sessions
    /// - Returns: Array of tracked sessions
    func getAllTrackedSessions() -> [HTTPSession] {
        return sessionQueue.sync {
            return Array(trackedSessions.values)
        }
    }
    
    /// Gets the count of tracked sessions
    /// - Returns: Number of tracked sessions
    func getTrackedSessionCount() -> Int {
        return sessionQueue.sync {
            return trackedSessions.count
        }
    }
    
    // MARK: - Observer Management
    
    /// Adds a session observer
    /// - Parameter observer: The observer to add
    func addObserver(_ observer: SessionObserver) {
        sessionQueue.async {
            self.observers.append(observer)
        }
    }
    
    /// Removes a session observer
    /// - Parameter observer: The observer to remove
    func removeObserver(_ observer: SessionObserver) {
        sessionQueue.async {
            self.observers.removeAll { $0 === observer }
        }
    }
    
    // MARK: - Private Methods
    
    /// Notifies all observers with a given action
    /// - Parameter action: The action to perform on each observer
    private func notifyObservers(_ action: @escaping (SessionObserver) -> Void) {
        for observer in observers {
            DispatchQueue.main.async {
                action(observer)
            }
        }
    }
}

// MARK: - SessionObserver Protocol

/// Protocol for observing session lifecycle events
internal protocol SessionObserver: AnyObject {
    /// Called when a session is started
    /// - Parameter session: The started session
    func sessionStarted(_ session: HTTPSession)
    
    /// Called when a session is updated
    /// - Parameter session: The updated session
    func sessionUpdated(_ session: HTTPSession)
    
    /// Called when a session is completed
    /// - Parameter session: The completed session
    func sessionCompleted(_ session: HTTPSession)
    
    /// Called when a session is removed from tracking
    /// - Parameter session: The removed session
    func sessionRemoved(_ session: HTTPSession)
}