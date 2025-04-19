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
    
    /// カスタムメタデータのための型エイリアス
    public typealias Metadata = [String: String]
    
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
        self.metadata = metadata
        self.queuedTime = queuedTime
        self.retryCount = retryCount
        self.usedSSLDecryption = usedSSLDecryption
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
    
    /// メタデータを追加または更新
    /// - Parameters:
    ///   - key: メタデータのキー
    ///   - value: メタデータの値
    /// - Returns: 更新されたセッション
    public func addMetadata(key: String, value: String) -> HTTPSession {
        var updated = self
        updated.metadata[key] = value
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
                desc += "  \(key): \(value)\n"
            }
        }
        
        if retryCount > 0 {
            desc += "Retries: \(retryCount)\n"
        }
        
        return desc
    }
} 