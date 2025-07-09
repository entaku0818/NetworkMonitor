import Foundation

/// フィルタリング条件を定義するプロトコル
public protocol FilterCriteriaProtocol {
    /// セッションがこの条件にマッチするかどうかを判定する
    /// - Parameter session: 判定対象のHTTPセッション
    /// - Returns: 条件にマッチする場合はtrue、それ以外はfalse
    func matches(session: HTTPSession) -> Bool
}

/// 基本的なフィルタリング条件を提供するクラス
/// 複数の条件を組み合わせて複合的なフィルタリングが可能
public class FilterCriteria: FilterCriteriaProtocol {
    
    /// 論理演算子
    public enum LogicalOperator {
        case and
        case or
    }
    
    /// フィルター条件の種類
    public enum FilterType {
        case url(pattern: String, isRegex: Bool = false)
        case host(pattern: String, isRegex: Bool = false)
        case path(pattern: String, isRegex: Bool = false)
        case method(HTTPRequest.Method)
        case statusCode(Int)
        case statusCodeRange(Range<Int>)
        case statusCategory(HTTPResponse.StatusCodeCategory)
        case contentType(String)
        case hasRequestBody
        case hasResponseBody
        case duration(min: TimeInterval?, max: TimeInterval?)
        case timestamp(from: Date?, to: Date?)
        case metadata(key: String, value: HTTPSession.MetadataValue?)
        case hasError
        case fromCache
        case sslDecryption
        case retryCount(min: Int?, max: Int?)
    }
    
    private var conditions: [(FilterType, LogicalOperator?)] = []
    
    /// 初期化
    public init() {}
    
    // MARK: - Condition Building Methods
    
    /// URLパターンでフィルタリング
    /// - Parameters:
    ///   - pattern: マッチするパターン
    ///   - isRegex: 正規表現として扱うかどうか
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func url(pattern: String, isRegex: Bool = false, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.url(pattern: pattern, isRegex: isRegex), operator: logicalOperator)
        return self
    }
    
    /// ホスト名でフィルタリング
    /// - Parameters:
    ///   - pattern: マッチするパターン
    ///   - isRegex: 正規表現として扱うかどうか
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func host(pattern: String, isRegex: Bool = false, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.host(pattern: pattern, isRegex: isRegex), operator: logicalOperator)
        return self
    }
    
    /// パス名でフィルタリング
    /// - Parameters:
    ///   - pattern: マッチするパターン
    ///   - isRegex: 正規表現として扱うかどうか
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func path(pattern: String, isRegex: Bool = false, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.path(pattern: pattern, isRegex: isRegex), operator: logicalOperator)
        return self
    }
    
    /// HTTPメソッドでフィルタリング
    /// - Parameters:
    ///   - method: HTTPメソッド
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func method(_ method: HTTPRequest.Method, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.method(method), operator: logicalOperator)
        return self
    }
    
    /// ステータスコードでフィルタリング
    /// - Parameters:
    ///   - statusCode: ステータスコード
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func statusCode(_ statusCode: Int, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.statusCode(statusCode), operator: logicalOperator)
        return self
    }
    
    /// ステータスコード範囲でフィルタリング
    /// - Parameters:
    ///   - range: ステータスコードの範囲
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func statusCodeRange(_ range: Range<Int>, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.statusCodeRange(range), operator: logicalOperator)
        return self
    }
    
    /// ステータスコードカテゴリでフィルタリング
    /// - Parameters:
    ///   - category: ステータスコードカテゴリ
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func statusCategory(_ category: HTTPResponse.StatusCodeCategory, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.statusCategory(category), operator: logicalOperator)
        return self
    }
    
    /// Content-Typeでフィルタリング
    /// - Parameters:
    ///   - contentType: Content-Type文字列
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func contentType(_ contentType: String, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.contentType(contentType), operator: logicalOperator)
        return self
    }
    
    /// リクエストボディの有無でフィルタリング
    /// - Parameter logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func hasRequestBody(logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.hasRequestBody, operator: logicalOperator)
        return self
    }
    
    /// レスポンスボディの有無でフィルタリング
    /// - Parameter logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func hasResponseBody(logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.hasResponseBody, operator: logicalOperator)
        return self
    }
    
    /// レスポンス時間でフィルタリング
    /// - Parameters:
    ///   - min: 最小時間（秒）
    ///   - max: 最大時間（秒）
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func duration(min: TimeInterval? = nil, max: TimeInterval? = nil, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.duration(min: min, max: max), operator: logicalOperator)
        return self
    }
    
    /// タイムスタンプでフィルタリング
    /// - Parameters:
    ///   - from: 開始日時
    ///   - to: 終了日時
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func timestamp(from: Date? = nil, to: Date? = nil, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.timestamp(from: from, to: to), operator: logicalOperator)
        return self
    }
    
    /// メタデータでフィルタリング
    /// - Parameters:
    ///   - key: メタデータのキー
    ///   - value: メタデータの値（nilの場合はキーの存在のみを確認）
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func metadata(key: String, value: HTTPSession.MetadataValue? = nil, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.metadata(key: key, value: value), operator: logicalOperator)
        return self
    }
    
    /// エラーの有無でフィルタリング
    /// - Parameter logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func hasError(logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.hasError, operator: logicalOperator)
        return self
    }
    
    /// キャッシュからの取得でフィルタリング
    /// - Parameter logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func fromCache(logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.fromCache, operator: logicalOperator)
        return self
    }
    
    /// SSL解読の使用でフィルタリング
    /// - Parameter logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func usedSSLDecryption(logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.sslDecryption, operator: logicalOperator)
        return self
    }
    
    /// リトライ回数でフィルタリング
    /// - Parameters:
    ///   - min: 最小リトライ回数
    ///   - max: 最大リトライ回数
    ///   - logicalOperator: 論理演算子（デフォルトは.and）
    /// - Returns: 自身のインスタンス（メソッドチェーン用）
    @discardableResult
    public func retryCount(min: Int? = nil, max: Int? = nil, logicalOperator: LogicalOperator = .and) -> FilterCriteria {
        addCondition(.retryCount(min: min, max: max), operator: logicalOperator)
        return self
    }
    
    // MARK: - Private Helper Methods
    
    private func addCondition(_ filterType: FilterType, operator: LogicalOperator) {
        if conditions.isEmpty {
            // 最初の条件の場合は演算子は不要
            conditions.append((filterType, nil))
        } else {
            conditions.append((filterType, `operator`))
        }
    }
    
    // MARK: - FilterCriteriaProtocol Implementation
    
    public func matches(session: HTTPSession) -> Bool {
        guard !conditions.isEmpty else { return true }
        
        var result = evaluateCondition(conditions[0].0, session: session)
        
        for i in 1..<conditions.count {
            let (condition, logicalOperator) = conditions[i]
            let conditionResult = evaluateCondition(condition, session: session)
            
            switch logicalOperator {
            case .and:
                result = result && conditionResult
            case .or:
                result = result || conditionResult
            case .none:
                // これは通常発生しないが、安全のため
                result = result && conditionResult
            }
        }
        
        return result
    }
    
    private func evaluateCondition(_ filterType: FilterType, session: HTTPSession) -> Bool {
        switch filterType {
        case .url(let pattern, let isRegex):
            return matchesPattern(session.url, pattern: pattern, isRegex: isRegex)
            
        case .host(let pattern, let isRegex):
            guard let host = session.host else { return false }
            return matchesPattern(host, pattern: pattern, isRegex: isRegex)
            
        case .path(let pattern, let isRegex):
            guard let path = session.path else { return false }
            return matchesPattern(path, pattern: pattern, isRegex: isRegex)
            
        case .method(let method):
            return session.request.method == method
            
        case .statusCode(let statusCode):
            return session.statusCode == statusCode
            
        case .statusCodeRange(let range):
            guard let statusCode = session.statusCode else { return false }
            return range.contains(statusCode)
            
        case .statusCategory(let category):
            return session.response?.statusCategory == category
            
        case .contentType(let contentType):
            return session.response?.headers["Content-Type"]?.contains(contentType) == true
            
        case .hasRequestBody:
            return session.request.body != nil && !session.request.body!.isEmpty
            
        case .hasResponseBody:
            return session.response?.body != nil && !session.response!.body!.isEmpty
            
        case .duration(let min, let max):
            let duration = session.duration
            if let min = min, duration < min { return false }
            if let max = max, duration > max { return false }
            return true
            
        case .timestamp(let from, let to):
            let timestamp = session.startTime
            if let from = from, timestamp < from { return false }
            if let to = to, timestamp > to { return false }
            return true
            
        case .metadata(let key, let value):
            guard let sessionValue = session.metadata[key] else { return false }
            if let expectedValue = value {
                return sessionValue == expectedValue
            }
            return true // キーの存在のみを確認
            
        case .hasError:
            return session.response?.isError == true
            
        case .fromCache:
            return session.response?.fromCache == true
            
        case .sslDecryption:
            return session.usedSSLDecryption
            
        case .retryCount(let min, let max):
            let retryCount = session.retryCount
            if let min = min, retryCount < min { return false }
            if let max = max, retryCount > max { return false }
            return true
        }
    }
    
    private func matchesPattern(_ text: String, pattern: String, isRegex: Bool) -> Bool {
        if isRegex {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: text.utf16.count)
                return regex.firstMatch(in: text, options: [], range: range) != nil
            } catch {
                // 正規表現が無効な場合は文字列一致で代替
                return text.contains(pattern)
            }
        } else {
            return text.contains(pattern)
        }
    }
    
    // MARK: - Utility Methods
    
    /// すべての条件をクリア
    public func clearAll() -> FilterCriteria {
        conditions.removeAll()
        return self
    }
    
    /// 条件が設定されているかどうか
    public var hasConditions: Bool {
        return !conditions.isEmpty
    }
    
    /// 設定されている条件の数
    public var conditionCount: Int {
        return conditions.count
    }
}

// MARK: - Predefined Filter Extensions

public extension FilterCriteria {
    
    /// 成功レスポンス（2xx）のみを表示
    static func successOnly() -> FilterCriteria {
        return FilterCriteria().statusCategory(.success)
    }
    
    /// エラーレスポンス（4xx, 5xx）のみを表示
    static func errorsOnly() -> FilterCriteria {
        return FilterCriteria()
            .statusCategory(.clientError, logicalOperator: .and)
            .statusCategory(.serverError, logicalOperator: .or)
    }
    
    /// 特定のホストのみを表示
    /// - Parameter host: ホスト名
    /// - Returns: フィルター条件
    static func host(_ host: String) -> FilterCriteria {
        return FilterCriteria().host(pattern: host)
    }
    
    /// 遅いリクエスト（指定時間以上）のみを表示
    /// - Parameter threshold: 閾値（秒）
    /// - Returns: フィルター条件
    static func slowRequests(threshold: TimeInterval = 2.0) -> FilterCriteria {
        return FilterCriteria().duration(min: threshold)
    }
    
    /// JSONレスポンスのみを表示
    static func jsonOnly() -> FilterCriteria {
        return FilterCriteria().contentType("application/json")
    }
    
    /// 画像リクエストのみを表示
    static func imagesOnly() -> FilterCriteria {
        return FilterCriteria()
            .contentType("image/", logicalOperator: .and)
    }
}