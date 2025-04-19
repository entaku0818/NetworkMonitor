import Foundation

/// HTTPセッションを表すモデル。
/// リクエストとレスポンスの組み合わせ、およびそれに関連するタイミング情報やメタデータを格納します。
public struct HTTPSession: Codable, Identifiable {
    
    /// セッションの状態を表す列挙型
    public enum State: String, Codable {
        /// 初期化済み、リクエスト作成済み
        case initialized
        
        /// リクエスト送信中
        case sending
        
        /// レスポンス待機中
        case waiting
        
        /// レスポンス受信中
        case receiving
        
        /// 完了
        case completed
        
        /// 失敗
        case failed
        
        /// キャンセル
        case cancelled
    }
    
    /// カスタムメタデータ値の型
    public enum MetadataValue: Codable, Equatable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case date(Date)
        
        // Codable実装
        private enum CodingKeys: String, CodingKey {
            case type, value
        }
        
        private enum ValueType: String, Codable {
            case string, int, double, bool, date
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(ValueType.self, forKey: .type)
            
            switch type {
            case .string:
                let value = try container.decode(String.self, forKey: .value)
                self = .string(value)
            case .int:
                let value = try container.decode(Int.self, forKey: .value)
                self = .int(value)
            case .double:
                let value = try container.decode(Double.self, forKey: .value)
                self = .double(value)
            case .bool:
                let value = try container.decode(Bool.self, forKey: .value)
                self = .bool(value)
            case .date:
                let value = try container.decode(Date.self, forKey: .value)
                self = .date(value)
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .string(let value):
                try container.encode(ValueType.string, forKey: .type)
                try container.encode(value, forKey: .value)
            case .int(let value):
                try container.encode(ValueType.int, forKey: .type)
                try container.encode(value, forKey: .value)
            case .double(let value):
                try container.encode(ValueType.double, forKey: .type)
                try container.encode(value, forKey: .value)
            case .bool(let value):
                try container.encode(ValueType.bool, forKey: .type)
                try container.encode(value, forKey: .value)
            case .date(let value):
                try container.encode(ValueType.date, forKey: .type)
                try container.encode(value, forKey: .value)
            }
        }
        
        // 文字列化するメソッド
        public var stringValue: String {
            switch self {
            case .string(let value): return value
            case .int(let value): return String(value)
            case .double(let value): return String(value)
            case .bool(let value): return String(value)
            case .date(let value): 
                let formatter = ISO8601DateFormatter()
                return formatter.string(from: value)
            }
        }
    }
    
    /// カスタムメタデータのための型エイリアス
    public typealias Metadata = [String: MetadataValue]
    
    /// 旧メタデータ（文字列のみ）から新メタデータ形式に変換
    public static func convertLegacyMetadata(_ legacyMetadata: [String: String]) -> Metadata {
        var newMetadata: Metadata = [:]
        
        for (key, value) in legacyMetadata {
            newMetadata[key] = .string(value)
        }
        
        return newMetadata
    }
    
    /// セッションの一意のID
    public let id: UUID
    
    /// HTTPリクエスト
    public private(set) var request: HTTPRequest
    
    /// HTTPレスポンス（存在する場合）
    public private(set) var response: HTTPResponse?
    
    /// セッションの現在の状態
    public private(set) var state: State
    
    /// セッションの開始時刻
    public let startTime: Date
    
    /// レスポンスの受信開始時刻（存在する場合）
    public private(set) var responseStartTime: Date?
    
    /// セッションの終了時刻（存在する場合）
    public private(set) var endTime: Date?
    
    /// セッションの合計所要時間（秒）、計算プロパティ
    public var duration: TimeInterval {
        if let end = endTime {
            return end.timeIntervalSince(startTime)
        } else if let responseStart = responseStartTime {
            // レスポンス受信中の場合は現在までの時間を返す
            return Date().timeIntervalSince(responseStart) + (response?.duration ?? 0)
        } else {
            // リクエスト中またはレスポンス待ち中の場合
            return Date().timeIntervalSince(startTime)
        }
    }
    
    /// リクエスト送信にかかった時間（秒）
    public private(set) var requestDuration: TimeInterval?
    
    /// カスタムメタデータ
    public private(set) var metadata: Metadata
    
    /// リクエストのキューイング時刻（バックグラウンドタスクなど用）
    public private(set) var queuedTime: Date?
    
    /// リトライ回数
    public private(set) var retryCount: Int
    
    /// このセッションがSSL解読を使用したかどうか
    public let usedSSLDecryption: Bool
    
    /// 関連セッションのID
    public private(set) var relatedSessionIDs: [UUID]
    
    /// 親セッションのID（ある場合）
    public let parentSessionID: UUID?
    
    /// 初期化
    /// - Parameters:
    ///   - id: セッションの一意のID（デフォルトは自動生成）
    ///   - request: HTTPリクエスト
    ///   - response: HTTPレスポンス（あれば）
    ///   - state: セッションの状態（デフォルトは.initialized）
    ///   - startTime: セッションの開始時刻（デフォルトは現在時刻）
    ///   - responseStartTime: レスポンスの受信開始時刻（オプション）
    ///   - endTime: セッションの終了時刻（オプション）
    ///   - requestDuration: リクエスト送信にかかった時間（秒）
    ///   - metadata: カスタムメタデータ（デフォルトは空）
    ///   - queuedTime: リクエストのキューイング時刻（オプション）
    ///   - retryCount: リトライ回数（デフォルトは0）
    ///   - usedSSLDecryption: SSL解読が使用されたかどうか（デフォルトはfalse）
    ///   - relatedSessionIDs: 関連セッションのID配列
    ///   - parentSessionID: 親セッションのID（ある場合）
    public init(
        id: UUID = UUID(),
        request: HTTPRequest,
        response: HTTPResponse? = nil,
        state: State = .initialized,
        startTime: Date = Date(),
        responseStartTime: Date? = nil,
        endTime: Date? = nil,
        requestDuration: TimeInterval? = nil,
        metadata: Metadata = [:],
        queuedTime: Date? = nil,
        retryCount: Int = 0,
        usedSSLDecryption: Bool = false,
        relatedSessionIDs: [UUID] = [],
        parentSessionID: UUID? = nil
    ) {
        self.id = id
        self.request = request
        self.response = response
        self.state = state
        self.startTime = startTime
        self.responseStartTime = responseStartTime
        self.endTime = endTime
        self.requestDuration = requestDuration
        self.metadata = metadata
        self.queuedTime = queuedTime
        self.retryCount = retryCount
        self.usedSSLDecryption = usedSSLDecryption
        self.relatedSessionIDs = relatedSessionIDs
        self.parentSessionID = parentSessionID
    }
    
    /// 旧フォーマットのメタデータでの初期化（後方互換性のため）
    /// - Parameters:
    ///   - id: セッションの一意のID
    ///   - request: HTTPリクエスト
    ///   - response: HTTPレスポンス（あれば）
    ///   - state: セッションの状態
    ///   - startTime: セッションの開始時刻
    ///   - responseStartTime: レスポンスの受信開始時刻
    ///   - endTime: セッションの終了時刻
    ///   - requestDuration: リクエスト送信にかかった時間
    ///   - legacyMetadata: 文字列ベースの古いメタデータ形式
    ///   - queuedTime: リクエストのキューイング時刻
    ///   - retryCount: リトライ回数
    ///   - usedSSLDecryption: SSL解読が使用されたかどうか
    public init(
        id: UUID = UUID(),
        request: HTTPRequest,
        response: HTTPResponse? = nil,
        state: State = .initialized,
        startTime: Date = Date(),
        responseStartTime: Date? = nil,
        endTime: Date? = nil,
        requestDuration: TimeInterval? = nil,
        legacyMetadata: [String: String] = [:],
        queuedTime: Date? = nil,
        retryCount: Int = 0,
        usedSSLDecryption: Bool = false
    ) {
        self.id = id
        self.request = request
        self.response = response
        self.state = state
        self.startTime = startTime
        self.responseStartTime = responseStartTime
        self.endTime = endTime
        self.requestDuration = requestDuration
        self.metadata = HTTPSession.convertLegacyMetadata(legacyMetadata)
        self.queuedTime = queuedTime
        self.retryCount = retryCount
        self.usedSSLDecryption = usedSSLDecryption
        self.relatedSessionIDs = []
        self.parentSessionID = nil
    }
    
    // MARK: - 状態管理用メソッド
    
    /// リクエスト送信中の状態に更新
    /// - Returns: 更新されたセッション
    public func sending() -> HTTPSession {
        var updated = self
        updated.state = .sending
        return updated
    }
    
    /// レスポンス待機中の状態に更新
    /// - Parameter requestDuration: リクエスト送信にかかった時間
    /// - Returns: 更新されたセッション
    public func waiting(requestDuration: TimeInterval) -> HTTPSession {
        var updated = self
        updated.state = .waiting
        updated.requestDuration = requestDuration
        return updated
    }
    
    /// レスポンス受信中の状態に更新
    /// - Parameter responseStartTime: レスポンスの受信開始時刻
    /// - Returns: 更新されたセッション
    public func receiving(responseStartTime: Date = Date()) -> HTTPSession {
        var updated = self
        updated.state = .receiving
        updated.responseStartTime = responseStartTime
        return updated
    }
    
    /// 完了状態に更新
    /// - Parameters:
    ///   - response: 受信したHTTPレスポンス
    ///   - endTime: セッションの終了時刻
    /// - Returns: 更新されたセッション
    public func completed(response: HTTPResponse, endTime: Date = Date()) -> HTTPSession {
        var updated = self
        updated.state = .completed
        updated.response = response
        updated.endTime = endTime
        return updated
    }
    
    /// 失敗状態に更新
    /// - Parameters:
    ///   - error: 発生したエラー
    ///   - endTime: セッションの終了時刻
    /// - Returns: 更新されたセッション
    public func failed(error: Error, endTime: Date = Date()) -> HTTPSession {
        var updated = self
        updated.state = .failed
        
        // エラーを含むHTTPResponseを作成
        updated.response = HTTPResponse(
            statusCode: 0,
            headers: [:],
            body: nil,
            timestamp: endTime,
            duration: endTime.timeIntervalSince(startTime),
            error: error
        )
        updated.endTime = endTime
        return updated
    }
    
    /// キャンセル状態に更新
    /// - Parameter endTime: セッションの終了時刻
    /// - Returns: 更新されたセッション
    public func cancelled(endTime: Date = Date()) -> HTTPSession {
        var updated = self
        updated.state = .cancelled
        updated.endTime = endTime
        return updated
    }
    
    /// リトライカウントを増加
    /// - Returns: 更新されたセッション
    public func incrementRetry() -> HTTPSession {
        var updated = self
        updated.retryCount += 1
        return updated
    }
    
    // MARK: - メタデータ管理
    
    /// メタデータを追加または更新（文字列値）
    /// - Parameters:
    ///   - key: メタデータのキー
    ///   - value: メタデータの文字列値
    /// - Returns: 更新されたセッション
    public func addMetadata(key: String, value: String) -> HTTPSession {
        var updated = self
        updated.metadata[key] = .string(value)
        return updated
    }
    
    /// メタデータを追加または更新（整数値）
    /// - Parameters:
    ///   - key: メタデータのキー
    ///   - value: メタデータの整数値
    /// - Returns: 更新されたセッション
    public func addMetadata(key: String, value: Int) -> HTTPSession {
        var updated = self
        updated.metadata[key] = .int(value)
        return updated
    }
    
    /// メタデータを追加または更新（浮動小数点値）
    /// - Parameters:
    ///   - key: メタデータのキー
    ///   - value: メタデータの浮動小数点値
    /// - Returns: 更新されたセッション
    public func addMetadata(key: String, value: Double) -> HTTPSession {
        var updated = self
        updated.metadata[key] = .double(value)
        return updated
    }
    
    /// メタデータを追加または更新（真偽値）
    /// - Parameters:
    ///   - key: メタデータのキー
    ///   - value: メタデータの真偽値
    /// - Returns: 更新されたセッション
    public func addMetadata(key: String, value: Bool) -> HTTPSession {
        var updated = self
        updated.metadata[key] = .bool(value)
        return updated
    }
    
    /// メタデータを追加または更新（日付値）
    /// - Parameters:
    ///   - key: メタデータのキー
    ///   - value: メタデータの日付値
    /// - Returns: 更新されたセッション
    public func addMetadata(key: String, value: Date) -> HTTPSession {
        var updated = self
        updated.metadata[key] = .date(value)
        return updated
    }
    
    /// 複数のメタデータを追加または更新
    /// - Parameter newMetadata: 追加するメタデータ
    /// - Returns: 更新されたセッション
    public func addMetadata(_ newMetadata: Metadata) -> HTTPSession {
        var updated = self
        updated.metadata.merge(newMetadata) { (_, new) in new }
        return updated
    }
    
    /// メタデータを削除
    /// - Parameter key: 削除するメタデータのキー
    /// - Returns: 更新されたセッション
    public func removeMetadata(key: String) -> HTTPSession {
        var updated = self
        updated.metadata.removeValue(forKey: key)
        return updated
    }
    
    // MARK: - 関連セッション管理
    
    /// 関連セッションを追加
    /// - Parameter sessionID: 関連付けるセッションのID
    /// - Returns: 更新されたセッション
    public func addRelatedSession(sessionID: UUID) -> HTTPSession {
        var updated = self
        if !updated.relatedSessionIDs.contains(sessionID) {
            updated.relatedSessionIDs.append(sessionID)
        }
        return updated
    }
    
    /// 関連セッションを削除
    /// - Parameter sessionID: 関連付けを解除するセッションのID
    /// - Returns: 更新されたセッション
    public func removeRelatedSession(sessionID: UUID) -> HTTPSession {
        var updated = self
        updated.relatedSessionIDs.removeAll { $0 == sessionID }
        return updated
    }
    
    /// 子セッションを作成
    /// - Parameter request: 新しいリクエスト
    /// - Returns: 親セッションIDとして現在のセッションIDを持つ新しいセッション
    public func createChildSession(request: HTTPRequest) -> HTTPSession {
        return HTTPSession(
            request: request,
            parentSessionID: self.id
        )
    }
    
    // MARK: - 便利なアクセサメソッド
    
    /// HTTPメソッド
    public var httpMethod: String {
        return request.method.rawValue
    }
    
    /// URL文字列
    public var url: String {
        return request.url
    }
    
    /// URLのホスト部分
    public var host: String? {
        return request.urlComponents?.host
    }
    
    /// URLのパス部分
    public var path: String? {
        return request.urlComponents?.path
    }
    
    /// ステータスコード（存在する場合）
    public var statusCode: Int? {
        return response?.statusCode
    }
    
    /// セッションが完了しているかどうか
    public var isCompleted: Bool {
        return state == .completed
    }
    
    /// セッションが失敗したかどうか
    public var isFailed: Bool {
        return state == .failed
    }
    
    /// セッションがキャンセルされたかどうか
    public var isCancelled: Bool {
        return state == .cancelled
    }
    
    /// セッションが終了したかどうか（完了、失敗、キャンセルのいずれか）
    public var isFinished: Bool {
        return isCompleted || isFailed || isCancelled
    }
    
    /// セッションが進行中かどうか
    public var isOngoing: Bool {
        return !isFinished
    }
    
    /// 子セッションがあるかどうか
    public var hasChildren: Bool {
        return !relatedSessionIDs.isEmpty
    }
    
    /// 親セッションがあるかどうか
    public var hasParent: Bool {
        return parentSessionID != nil
    }
}

// MARK: - Equatable
extension HTTPSession: Equatable {
    public static func == (lhs: HTTPSession, rhs: HTTPSession) -> Bool {
        // IDが同じであれば同一と見なす
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable
extension HTTPSession: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - CustomStringConvertible
extension HTTPSession: CustomStringConvertible {
    public var description: String {
        var desc = "[\(httpMethod)] \(url)\n"
        desc += "State: \(state.rawValue)\n"
        
        if let statusCode = statusCode {
            desc += "Status: \(statusCode)\n"
        }
        
        desc += "Started: \(startTime)\n"
        
        if let endTime = endTime {
            desc += "Ended: \(endTime)\n"
        }
        
        desc += "Duration: \(String(format: "%.3f", duration))s\n"
        
        if !metadata.isEmpty {
            desc += "Metadata:\n"
            for (key, value) in metadata {
                desc += "  \(key): \(value.stringValue)\n"
            }
        }
        
        if retryCount > 0 {
            desc += "Retries: \(retryCount)\n"
        }
        
        if !relatedSessionIDs.isEmpty {
            desc += "Related Sessions: \(relatedSessionIDs.count)\n"
        }
        
        if let parentID = parentSessionID {
            desc += "Parent: \(parentID)\n"
        }
        
        return desc
    }
} 