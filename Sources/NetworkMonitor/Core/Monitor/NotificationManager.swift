import Foundation

/// Manages notifications for network monitoring events
internal class NotificationManager {
    
    // MARK: - Notification Names
    
    static let sessionStartedNotification = Notification.Name("NetworkMonitor.SessionStarted")
    static let sessionCompletedNotification = Notification.Name("NetworkMonitor.SessionCompleted")
    static let sessionFailedNotification = Notification.Name("NetworkMonitor.SessionFailed")
    static let sessionUpdatedNotification = Notification.Name("NetworkMonitor.SessionUpdated")
    
    // MARK: - UserInfo Keys
    
    static let sessionKey = "session"
    static let errorKey = "error"
    
    // MARK: - Properties
    
    /// Notification center for posting events
    private let notificationCenter: NotificationCenter
    
    /// Queue for posting notifications
    private let notificationQueue = DispatchQueue(label: "com.networkmonitor.notifications", qos: .utility)
    
    // MARK: - Initialization
    
    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }
    
    // MARK: - Notification Methods
    
    /// Posts a notification when a session is started
    /// - Parameter session: The started session
    func sessionStarted(_ session: HTTPSession) {
        postNotification(
            name: Self.sessionStartedNotification,
            userInfo: [Self.sessionKey: session]
        )
    }
    
    /// Posts a notification when a session is completed
    /// - Parameter session: The completed session
    func sessionCompleted(_ session: HTTPSession) {
        postNotification(
            name: Self.sessionCompletedNotification,
            userInfo: [Self.sessionKey: session]
        )
    }
    
    /// Posts a notification when a session fails
    /// - Parameters:
    ///   - session: The failed session
    ///   - error: The error that caused the failure
    func sessionFailed(_ session: HTTPSession, error: Error) {
        postNotification(
            name: Self.sessionFailedNotification,
            userInfo: [
                Self.sessionKey: session,
                Self.errorKey: error
            ]
        )
    }
    
    /// Posts a notification when a session is updated
    /// - Parameter session: The updated session
    func sessionUpdated(_ session: HTTPSession) {
        postNotification(
            name: Self.sessionUpdatedNotification,
            userInfo: [Self.sessionKey: session]
        )
    }
    
    // MARK: - Private Methods
    
    /// Posts a notification on the notification queue
    /// - Parameters:
    ///   - name: The notification name
    ///   - userInfo: The user info dictionary
    private func postNotification(name: Notification.Name, userInfo: [String: Any]) {
        notificationQueue.async {
            DispatchQueue.main.async {
                self.notificationCenter.post(
                    name: name,
                    object: self,
                    userInfo: userInfo
                )
            }
        }
    }
}

// MARK: - Public Extensions for Notification Observers

public extension NetworkMonitor {
    
    /// Notification names for observing network monitoring events
    enum NotificationName {
        /// Posted when a network session is started
        public static let sessionStarted = NotificationManager.sessionStartedNotification
        
        /// Posted when a network session is completed
        public static let sessionCompleted = NotificationManager.sessionCompletedNotification
        
        /// Posted when a network session fails
        public static let sessionFailed = NotificationManager.sessionFailedNotification
        
        /// Posted when a network session is updated
        public static let sessionUpdated = NotificationManager.sessionUpdatedNotification
    }
    
    /// Keys for accessing notification user info
    enum NotificationUserInfoKey {
        /// Key for accessing the HTTPSession object in notification userInfo
        public static let session = NotificationManager.sessionKey
        
        /// Key for accessing the Error object in notification userInfo
        public static let error = NotificationManager.errorKey
    }
}