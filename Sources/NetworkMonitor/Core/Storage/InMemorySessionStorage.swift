import Foundation

/// インメモリベースのセッションストレージ実装
/// 高速なアクセスが必要な場合や一時的な保存に適している
public class InMemorySessionStorage: SessionStorageProtocol {
    
    /// インメモリストレージのエラー種別
    public enum MemoryStorageError: Error, LocalizedError {
        case memoryLimitExceeded
        case sessionNotFound
        case operationFailed
        
        public var errorDescription: String? {
            switch self {
            case .memoryLimitExceeded: return "Memory limit exceeded"
            case .sessionNotFound: return "Session not found"
            case .operationFailed: return "Operation failed"
            }
        }
    }
    
    /// インメモリストレージの設定
    public struct Configuration {
        /// 最大保存セッション数
        public let maxSessions: Int
        /// 自動クリーンアップを有効にするか
        public let autoCleanup: Bool
        /// 古いセッションの保持期間（秒）
        public let retentionPeriod: TimeInterval
        /// メモリ使用量の上限（バイト）
        public let maxMemoryUsage: Int64
        /// データ圧縮を有効にするか
        public let compressionEnabled: Bool
        
        public init(
            maxSessions: Int = 1000,
            autoCleanup: Bool = true,
            retentionPeriod: TimeInterval = 60 * 60, // 1時間
            maxMemoryUsage: Int64 = 100 * 1024 * 1024, // 100MB
            compressionEnabled: Bool = false
        ) {
            self.maxSessions = maxSessions
            self.autoCleanup = autoCleanup
            self.retentionPeriod = retentionPeriod
            self.maxMemoryUsage = maxMemoryUsage
            self.compressionEnabled = compressionEnabled
        }
    }
    
    private let configuration: Configuration
    private let queue = DispatchQueue(label: "com.networkmonitor.memory-storage", qos: .userInitiated)
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    // スレッドセーフなストレージ
    private var sessions: [UUID: HTTPSession] = [:]
    private var sessionOrder: [UUID] = [] // 挿入順序を保持
    private var sessionTimestamps: [UUID: Date] = [:] // アクセス時刻の追跡
    
    /// 初期化
    /// - Parameter configuration: ストレージ設定
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        
        // エンコーダー設定
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonDecoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - SessionStorageProtocol Implementation
    
    public func save(session: HTTPSession, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            do {
                try self.performSave(session: session)
                
                if self.configuration.autoCleanup {
                    self.performCleanupIfNeeded()
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func save(sessions: [HTTPSession], completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            do {
                for session in sessions {
                    try self.performSave(session: session)
                }
                
                if self.configuration.autoCleanup {
                    self.performCleanupIfNeeded()
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func load(sessionID: UUID, completion: @escaping (Result<HTTPSession?, Error>) -> Void) {
        queue.async {
            let session = self.sessions[sessionID]
            
            // アクセス時刻を更新
            if session != nil {
                self.sessionTimestamps[sessionID] = Date()
            }
            
            DispatchQueue.main.async {
                completion(.success(session))
            }
        }
    }
    
    public func loadAll(completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
        queue.async {
            let allSessions = Array(self.sessions.values)
            
            // タイムスタンプ順にソート（新しいものから）
            let sortedSessions = allSessions.sorted { $0.startTime > $1.startTime }
            
            DispatchQueue.main.async {
                completion(.success(sortedSessions))
            }
        }
    }
    
    public func load(matching criteria: FilterCriteriaProtocol, completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
        loadAll { result in
            switch result {
            case .success(let sessions):
                let filteredSessions = sessions.filter { criteria.matches(session: $0) }
                completion(.success(filteredSessions))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func delete(sessionID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            self.sessions.removeValue(forKey: sessionID)
            self.sessionTimestamps.removeValue(forKey: sessionID)
            
            if let index = self.sessionOrder.firstIndex(of: sessionID) {
                self.sessionOrder.remove(at: index)
            }
            
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }
    }
    
    public func deleteAll(completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            self.sessions.removeAll()
            self.sessionOrder.removeAll()
            self.sessionTimestamps.removeAll()
            
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }
    }
    
    public func delete(matching criteria: FilterCriteriaProtocol, completion: @escaping (Result<Int, Error>) -> Void) {
        load(matching: criteria) { result in
            switch result {
            case .success(let matchingSessions):
                self.queue.async {
                    var deletedCount = 0
                    
                    for session in matchingSessions {
                        if self.sessions.removeValue(forKey: session.id) != nil {
                            self.sessionTimestamps.removeValue(forKey: session.id)
                            
                            if let index = self.sessionOrder.firstIndex(of: session.id) {
                                self.sessionOrder.remove(at: index)
                            }
                            
                            deletedCount += 1
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(deletedCount))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    public func count(completion: @escaping (Result<Int, Error>) -> Void) {
        queue.async {
            let count = self.sessions.count
            DispatchQueue.main.async {
                completion(.success(count))
            }
        }
    }
    
    public func storageSize(completion: @escaping (Result<Int64, Error>) -> Void) {
        queue.async {
            do {
                let allSessions = Array(self.sessions.values)
                var totalSize: Int64 = 0
                
                for session in allSessions {
                    let data = try self.jsonEncoder.encode(session)
                    totalSize += Int64(data.count)
                }
                
                DispatchQueue.main.async {
                    completion(.success(totalSize))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performSave(session: HTTPSession) throws {
        // メモリ使用量チェック
        if sessions.count >= configuration.maxSessions {
            throw MemoryStorageError.memoryLimitExceeded
        }
        
        // 既存セッションの場合は更新、新規の場合は追加
        let isNewSession = sessions[session.id] == nil
        
        sessions[session.id] = session
        sessionTimestamps[session.id] = Date()
        
        if isNewSession {
            sessionOrder.append(session.id)
        }
    }
    
    private func performCleanupIfNeeded() {
        let currentTime = Date()
        var sessionsToRemove: [UUID] = []
        
        // 古いセッションの特定
        for (sessionID, timestamp) in sessionTimestamps {
            let age = currentTime.timeIntervalSince(timestamp)
            if age > configuration.retentionPeriod {
                sessionsToRemove.append(sessionID)
            }
        }
        
        // 古いセッションの削除
        for sessionID in sessionsToRemove {
            sessions.removeValue(forKey: sessionID)
            sessionTimestamps.removeValue(forKey: sessionID)
            
            if let index = sessionOrder.firstIndex(of: sessionID) {
                sessionOrder.remove(at: index)
            }
        }
        
        // 最大数を超えている場合の削除（古いものから）
        if sessionOrder.count > configuration.maxSessions {
            let excessCount = sessionOrder.count - configuration.maxSessions
            let sessionsToRemove = Array(sessionOrder.prefix(excessCount))
            
            for sessionID in sessionsToRemove {
                sessions.removeValue(forKey: sessionID)
                sessionTimestamps.removeValue(forKey: sessionID)
            }
            
            sessionOrder.removeFirst(excessCount)
        }
    }
    
    /// 現在のメモリ使用量を取得（概算）
    private func estimateMemoryUsage() throws -> Int64 {
        let allSessions = Array(sessions.values)
        var totalSize: Int64 = 0
        
        for session in allSessions {
            let data = try jsonEncoder.encode(session)
            totalSize += Int64(data.count)
        }
        
        return totalSize
    }
}

// MARK: - Convenience Extensions

public extension InMemorySessionStorage {
    
    /// メモリ統計情報を取得
    /// - Returns: メモリ使用状況の統計
    func getMemoryStatistics() -> MemoryStatistics {
        return MemoryStatistics(
            sessionCount: sessions.count,
            estimatedMemoryUsage: (try? estimateMemoryUsage()) ?? 0,
            maxSessions: configuration.maxSessions,
            maxMemoryUsage: configuration.maxMemoryUsage
        )
    }
    
    /// 全セッションをファイルストレージにエクスポート
    /// - Parameters:
    ///   - fileStorage: エクスポート先のファイルストレージ
    ///   - completion: 完了コールバック
    func export(to fileStorage: FileSessionStorage, completion: @escaping (Result<Void, Error>) -> Void) {
        loadAll { result in
            switch result {
            case .success(let sessions):
                fileStorage.save(sessions: sessions, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// ファイルストレージからセッションをインポート
    /// - Parameters:
    ///   - fileStorage: インポート元のファイルストレージ
    ///   - replaceExisting: 既存データを置き換えるか
    ///   - completion: 完了コールバック
    func importFrom(fileStorage: FileSessionStorage, replaceExisting: Bool = false, completion: @escaping (Result<Int, Error>) -> Void) {
        fileStorage.loadAll { result in
            switch result {
            case .success(let sessions):
                if replaceExisting {
                    self.deleteAll { deleteResult in
                        switch deleteResult {
                        case .success():
                            self.save(sessions: sessions) { saveResult in
                                switch saveResult {
                                case .success():
                                    completion(.success(sessions.count))
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                            }
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                } else {
                    self.save(sessions: sessions) { saveResult in
                        switch saveResult {
                        case .success():
                            completion(.success(sessions.count))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// 最近アクセスされたセッションを取得
    /// - Parameters:
    ///   - count: 取得するセッション数
    ///   - completion: 完了コールバック
    func getRecentlyAccessedSessions(count: Int, completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
        queue.async {
            let sortedSessions = self.sessionTimestamps.sorted { $0.value > $1.value }
            let recentSessionIDs = Array(sortedSessions.prefix(count).map { $0.key })
            
            let recentSessions = recentSessionIDs.compactMap { self.sessions[$0] }
            
            DispatchQueue.main.async {
                completion(.success(recentSessions))
            }
        }
    }
    
    /// 手動でクリーンアップを実行
    /// - Parameter completion: 完了コールバック
    func performManualCleanup(completion: @escaping (Result<Int, Error>) -> Void) {
        queue.async {
            let beforeCount = self.sessions.count
            self.performCleanupIfNeeded()
            let afterCount = self.sessions.count
            let cleanedCount = beforeCount - afterCount
            
            DispatchQueue.main.async {
                completion(.success(cleanedCount))
            }
        }
    }
}

// MARK: - Supporting Types

/// メモリ使用状況の統計情報
public struct MemoryStatistics {
    /// 現在のセッション数
    public let sessionCount: Int
    /// 推定メモリ使用量（バイト）
    public let estimatedMemoryUsage: Int64
    /// 最大セッション数
    public let maxSessions: Int
    /// 最大メモリ使用量（バイト）
    public let maxMemoryUsage: Int64
    
    /// メモリ使用率（0.0-1.0）
    public var memoryUsageRatio: Double {
        guard maxMemoryUsage > 0 else { return 0.0 }
        return Double(estimatedMemoryUsage) / Double(maxMemoryUsage)
    }
    
    /// セッション数使用率（0.0-1.0）
    public var sessionCountRatio: Double {
        guard maxSessions > 0 else { return 0.0 }
        return Double(sessionCount) / Double(maxSessions)
    }
    
    /// メモリ使用量を人間が読みやすい形式で取得
    public var humanReadableMemoryUsage: String {
        return ByteCountFormatter.string(fromByteCount: estimatedMemoryUsage, countStyle: .memory)
    }
}