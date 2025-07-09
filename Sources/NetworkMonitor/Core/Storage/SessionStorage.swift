import Foundation

/// セッションデータの保存・読み込みを管理するプロトコル
public protocol SessionStorageProtocol {
    /// セッションを保存する
    /// - Parameters:
    ///   - session: 保存するセッション
    ///   - completion: 完了コールバック
    func save(session: HTTPSession, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 複数のセッションを一括保存する
    /// - Parameters:
    ///   - sessions: 保存するセッション配列
    ///   - completion: 完了コールバック
    func save(sessions: [HTTPSession], completion: @escaping (Result<Void, Error>) -> Void)
    
    /// セッションを読み込む
    /// - Parameters:
    ///   - id: セッションID
    ///   - completion: 完了コールバック
    func load(sessionID: UUID, completion: @escaping (Result<HTTPSession?, Error>) -> Void)
    
    /// 全セッションを読み込む
    /// - Parameter completion: 完了コールバック
    func loadAll(completion: @escaping (Result<[HTTPSession], Error>) -> Void)
    
    /// フィルター条件に基づいてセッションを読み込む
    /// - Parameters:
    ///   - criteria: フィルター条件
    ///   - completion: 完了コールバック
    func load(matching criteria: FilterCriteriaProtocol, completion: @escaping (Result<[HTTPSession], Error>) -> Void)
    
    /// セッションを削除する
    /// - Parameters:
    ///   - id: セッションID
    ///   - completion: 完了コールバック
    func delete(sessionID: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 全セッションを削除する
    /// - Parameter completion: 完了コールバック
    func deleteAll(completion: @escaping (Result<Void, Error>) -> Void)
    
    /// 条件に基づいてセッションを削除する
    /// - Parameters:
    ///   - criteria: 削除条件
    ///   - completion: 完了コールバック
    func delete(matching criteria: FilterCriteriaProtocol, completion: @escaping (Result<Int, Error>) -> Void)
    
    /// 保存されているセッション数を取得
    /// - Parameter completion: 完了コールバック
    func count(completion: @escaping (Result<Int, Error>) -> Void)
    
    /// ストレージの使用量を取得
    /// - Parameter completion: 完了コールバック
    func storageSize(completion: @escaping (Result<Int64, Error>) -> Void)
}

/// ファイルベースのセッションストレージ実装
public class FileSessionStorage: SessionStorageProtocol {
    
    /// ストレージのエラー種別
    public enum StorageError: Error, LocalizedError {
        case fileNotFound
        case invalidFormat
        case writePermissionDenied
        case corruptedData
        case diskSpaceInsufficient
        case encodingFailed
        case decodingFailed
        
        public var errorDescription: String? {
            switch self {
            case .fileNotFound: return "File not found"
            case .invalidFormat: return "Invalid file format"
            case .writePermissionDenied: return "Write permission denied"
            case .corruptedData: return "Corrupted data"
            case .diskSpaceInsufficient: return "Insufficient disk space"
            case .encodingFailed: return "Encoding failed"
            case .decodingFailed: return "Decoding failed"
            }
        }
    }
    
    /// ファイル形式
    public enum FileFormat {
        case json
        case binaryPlist
        case custom
    }
    
    /// 保存設定
    public struct StorageConfiguration {
        /// ベースディレクトリ
        public let baseDirectory: URL
        /// ファイル形式
        public let fileFormat: FileFormat
        /// 最大保存セッション数
        public let maxSessions: Int
        /// 自動クリーンアップを有効にするか
        public let autoCleanup: Bool
        /// 古いセッションの保持期間（秒）
        public let retentionPeriod: TimeInterval
        /// 圧縮を有効にするか
        public let compressionEnabled: Bool
        
        public init(
            baseDirectory: URL? = nil,
            fileFormat: FileFormat = .json,
            maxSessions: Int = 10000,
            autoCleanup: Bool = true,
            retentionPeriod: TimeInterval = 30 * 24 * 60 * 60, // 30日
            compressionEnabled: Bool = false
        ) {
            self.baseDirectory = baseDirectory ?? Self.defaultDirectory()
            self.fileFormat = fileFormat
            self.maxSessions = maxSessions
            self.autoCleanup = autoCleanup
            self.retentionPeriod = retentionPeriod
            self.compressionEnabled = compressionEnabled
        }
        
        private static func defaultDirectory() -> URL {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return documentsPath.appendingPathComponent("NetworkMonitor").appendingPathComponent("Sessions")
        }
    }
    
    private let configuration: StorageConfiguration
    private let fileManager = FileManager.default
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let queue = DispatchQueue(label: "com.networkmonitor.storage", qos: .utility)
    
    /// 初期化
    /// - Parameter configuration: ストレージ設定
    public init(configuration: StorageConfiguration = StorageConfiguration()) {
        self.configuration = configuration
        
        // エンコーダー設定
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // デコーダー設定
        jsonDecoder.dateDecodingStrategy = .iso8601
        
        // ベースディレクトリを作成
        createBaseDirectoryIfNeeded()
    }
    
    // MARK: - SessionStorageProtocol Implementation
    
    public func save(session: HTTPSession, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            do {
                let fileURL = self.fileURL(for: session.id)
                let data = try self.encode(session: session)
                try data.write(to: fileURL)
                
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
                    let fileURL = self.fileURL(for: session.id)
                    let data = try self.encode(session: session)
                    try data.write(to: fileURL)
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
            do {
                let fileURL = self.fileURL(for: sessionID)
                
                guard self.fileManager.fileExists(atPath: fileURL.path) else {
                    DispatchQueue.main.async {
                        completion(.success(nil))
                    }
                    return
                }
                
                let data = try Data(contentsOf: fileURL)
                let session = try self.decode(session: data)
                
                DispatchQueue.main.async {
                    completion(.success(session))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func loadAll(completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
        queue.async {
            do {
                let sessionFiles = try self.getAllSessionFiles()
                var sessions: [HTTPSession] = []
                
                for fileURL in sessionFiles {
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let session = try self.decode(session: data)
                        sessions.append(session)
                    } catch {
                        // 個別ファイルの読み込みエラーは無視して続行
                        print("Failed to load session from \(fileURL.path): \(error)")
                    }
                }
                
                // タイムスタンプ順にソート
                sessions.sort { $0.startTime > $1.startTime }
                
                DispatchQueue.main.async {
                    completion(.success(sessions))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
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
            do {
                let fileURL = self.fileURL(for: sessionID)
                
                if self.fileManager.fileExists(atPath: fileURL.path) {
                    try self.fileManager.removeItem(at: fileURL)
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
    
    public func deleteAll(completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            do {
                let sessionFiles = try self.getAllSessionFiles()
                
                for fileURL in sessionFiles {
                    try self.fileManager.removeItem(at: fileURL)
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
    
    public func delete(matching criteria: FilterCriteriaProtocol, completion: @escaping (Result<Int, Error>) -> Void) {
        load(matching: criteria) { result in
            switch result {
            case .success(let sessions):
                let group = DispatchGroup()
                var deletedCount = 0
                var lastError: Error?
                
                for session in sessions {
                    group.enter()
                    self.delete(sessionID: session.id) { deleteResult in
                        switch deleteResult {
                        case .success():
                            deletedCount += 1
                        case .failure(let error):
                            lastError = error
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    if let error = lastError {
                        completion(.failure(error))
                    } else {
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
            do {
                let sessionFiles = try self.getAllSessionFiles()
                DispatchQueue.main.async {
                    completion(.success(sessionFiles.count))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func storageSize(completion: @escaping (Result<Int64, Error>) -> Void) {
        queue.async {
            do {
                let sessionFiles = try self.getAllSessionFiles()
                var totalSize: Int64 = 0
                
                for fileURL in sessionFiles {
                    let attributes = try self.fileManager.attributesOfItem(atPath: fileURL.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        totalSize += fileSize
                    }
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
    
    private func createBaseDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(at: configuration.baseDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create base directory: \(error)")
        }
    }
    
    private func fileURL(for sessionID: UUID) -> URL {
        let fileName = "\(sessionID.uuidString).\(fileExtension)"
        return configuration.baseDirectory.appendingPathComponent(fileName)
    }
    
    private var fileExtension: String {
        switch configuration.fileFormat {
        case .json: return "json"
        case .binaryPlist: return "plist"
        case .custom: return "nmdata"
        }
    }
    
    private func encode(session: HTTPSession) throws -> Data {
        switch configuration.fileFormat {
        case .json:
            return try jsonEncoder.encode(session)
        case .binaryPlist:
            return try PropertyListEncoder().encode(session)
        case .custom:
            // 将来的にカスタムバイナリ形式を実装
            return try jsonEncoder.encode(session)
        }
    }
    
    private func decode(session data: Data) throws -> HTTPSession {
        switch configuration.fileFormat {
        case .json:
            return try jsonDecoder.decode(HTTPSession.self, from: data)
        case .binaryPlist:
            return try PropertyListDecoder().decode(HTTPSession.self, from: data)
        case .custom:
            // 将来的にカスタムバイナリ形式を実装
            return try jsonDecoder.decode(HTTPSession.self, from: data)
        }
    }
    
    private func getAllSessionFiles() throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(at: configuration.baseDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        
        return contents.filter { url in
            url.pathExtension == fileExtension
        }.sorted { url1, url2 in
            // 更新日時順にソート
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
            return date1 > date2
        }
    }
    
    private func performCleanupIfNeeded() {
        do {
            let sessionFiles = try getAllSessionFiles()
            let currentTime = Date()
            
            // 古いファイルの削除
            for fileURL in sessionFiles {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let modificationDate = attributes[.modificationDate] as? Date {
                    let age = currentTime.timeIntervalSince(modificationDate)
                    if age > configuration.retentionPeriod {
                        try fileManager.removeItem(at: fileURL)
                    }
                }
            }
            
            // 最大数を超えている場合の削除（古いものから）
            let remainingFiles = try getAllSessionFiles()
            if remainingFiles.count > configuration.maxSessions {
                let filesToDelete = remainingFiles.suffix(remainingFiles.count - configuration.maxSessions)
                for fileURL in filesToDelete {
                    try fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            print("Cleanup failed: \(error)")
        }
    }
}

// MARK: - Convenience Extensions

public extension FileSessionStorage {
    
    /// セッションをエクスポートする
    /// - Parameters:
    ///   - sessions: エクスポートするセッション
    ///   - url: エクスポート先のURL
    ///   - format: エクスポート形式
    ///   - completion: 完了コールバック
    func export(sessions: [HTTPSession], to url: URL, format: FileFormat = .json, completion: @escaping (Result<Void, Error>) -> Void) {
        queue.async {
            do {
                let data: Data
                switch format {
                case .json:
                    data = try self.jsonEncoder.encode(sessions)
                case .binaryPlist:
                    data = try PropertyListEncoder().encode(sessions)
                case .custom:
                    data = try self.jsonEncoder.encode(sessions)
                }
                
                try data.write(to: url)
                
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
    
    /// セッションをインポートする
    /// - Parameters:
    ///   - url: インポート元のURL
    ///   - format: インポート形式
    ///   - completion: 完了コールバック
    func importSessions(from url: URL, format: FileFormat = .json, completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
        queue.async {
            do {
                let data = try Data(contentsOf: url)
                let sessions: [HTTPSession]
                
                switch format {
                case .json:
                    sessions = try self.jsonDecoder.decode([HTTPSession].self, from: data)
                case .binaryPlist:
                    sessions = try PropertyListDecoder().decode([HTTPSession].self, from: data)
                case .custom:
                    sessions = try self.jsonDecoder.decode([HTTPSession].self, from: data)
                }
                
                DispatchQueue.main.async {
                    completion(.success(sessions))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}