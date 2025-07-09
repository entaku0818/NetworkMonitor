import Foundation

/// セッション検索サービス
/// 高度な検索クエリと全文検索機能を提供
public class SessionSearchService {
    
    /// 検索結果
    public struct SearchResult {
        /// マッチしたセッション
        public let sessions: [HTTPSession]
        /// 検索に要した時間
        public let searchTime: TimeInterval
        /// 総セッション数
        public let totalCount: Int
        /// マッチした数
        public let matchCount: Int
        /// 検索クエリ
        public let query: SearchQuery
        /// ハイライト情報
        public let highlights: [UUID: [SearchHighlight]]
        
        /// マッチ率（0.0-1.0）
        public var matchRatio: Double {
            guard totalCount > 0 else { return 0.0 }
            return Double(matchCount) / Double(totalCount)
        }
    }
    
    /// 検索ハイライト情報
    public struct SearchHighlight {
        /// ハイライトするフィールド
        public let field: SearchField
        /// ハイライトする範囲
        public let range: NSRange
        /// マッチしたテキスト
        public let matchedText: String
    }
    
    /// 検索対象フィールド
    public enum SearchField: String, CaseIterable {
        case url = "url"
        case method = "method"
        case statusCode = "statusCode"
        case requestHeaders = "requestHeaders"
        case responseHeaders = "responseHeaders"
        case requestBody = "requestBody"
        case responseBody = "responseBody"
        case metadata = "metadata"
        case host = "host"
        case path = "path"
        case queryParameters = "queryParameters"
        
        public var displayName: String {
            switch self {
            case .url: return "URL"
            case .method: return "HTTPメソッド"
            case .statusCode: return "ステータスコード"
            case .requestHeaders: return "リクエストヘッダー"
            case .responseHeaders: return "レスポンスヘッダー"
            case .requestBody: return "リクエストボディ"
            case .responseBody: return "レスポンスボディ"
            case .metadata: return "メタデータ"
            case .host: return "ホスト"
            case .path: return "パス"
            case .queryParameters: return "クエリパラメータ"
            }
        }
    }
    
    /// 検索設定
    public struct SearchConfiguration {
        /// 大小文字を区別するか
        public let caseSensitive: Bool
        /// 正規表現を使用するか
        public let useRegex: Bool
        /// 全文検索を有効にするか
        public let fullTextSearch: Bool
        /// 検索対象フィールド
        public let searchFields: Set<SearchField>
        /// 検索結果の最大数
        public let maxResults: Int
        /// ハイライトを有効にするか
        public let enableHighlights: Bool
        /// 検索タイムアウト（秒）
        public let timeout: TimeInterval
        
        public init(
            caseSensitive: Bool = false,
            useRegex: Bool = false,
            fullTextSearch: Bool = true,
            searchFields: Set<SearchField> = Set(SearchField.allCases),
            maxResults: Int = 1000,
            enableHighlights: Bool = true,
            timeout: TimeInterval = 10.0
        ) {
            self.caseSensitive = caseSensitive
            self.useRegex = useRegex
            self.fullTextSearch = fullTextSearch
            self.searchFields = searchFields
            self.maxResults = maxResults
            self.enableHighlights = enableHighlights
            self.timeout = timeout
        }
    }
    
    private let configuration: SearchConfiguration
    private let queue = DispatchQueue(label: "com.networkmonitor.search", qos: .userInitiated)
    
    /// 初期化
    /// - Parameter configuration: 検索設定
    public init(configuration: SearchConfiguration = SearchConfiguration()) {
        self.configuration = configuration
    }
    
    // MARK: - Search Methods
    
    /// セッションを検索する
    /// - Parameters:
    ///   - query: 検索クエリ
    ///   - sessions: 検索対象のセッション配列
    ///   - completion: 完了コールバック
    public func search(query: SearchQuery, in sessions: [HTTPSession], completion: @escaping (Result<SearchResult, Error>) -> Void) {
        queue.async {
            let startTime = Date()
            
            do {
                let filteredSessions = try self.performSearch(query: query, sessions: sessions)
                let searchTime = Date().timeIntervalSince(startTime)
                
                let highlights = self.configuration.enableHighlights ? 
                    self.generateHighlights(for: filteredSessions, query: query) : [:]
                
                let result = SearchResult(
                    sessions: Array(filteredSessions.prefix(self.configuration.maxResults)),
                    searchTime: searchTime,
                    totalCount: sessions.count,
                    matchCount: filteredSessions.count,
                    query: query,
                    highlights: highlights
                )
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// ストレージ内を検索する
    /// - Parameters:
    ///   - query: 検索クエリ
    ///   - storage: 検索対象のストレージ
    ///   - completion: 完了コールバック
    public func search(query: SearchQuery, in storage: SessionStorageProtocol, completion: @escaping (Result<SearchResult, Error>) -> Void) {
        storage.loadAll { result in
            switch result {
            case .success(let sessions):
                self.search(query: query, in: sessions, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performSearch(query: SearchQuery, sessions: [HTTPSession]) throws -> [HTTPSession] {
        var results: [HTTPSession] = []
        
        for session in sessions {
            if try matchesSession(session: session, query: query) {
                results.append(session)
            }
        }
        
        // ソート
        switch query.sortBy {
        case .relevance:
            // 関連度でソート（実装は簡易版）
            results.sort { session1, session2 in
                let score1 = calculateRelevanceScore(session: session1, query: query)
                let score2 = calculateRelevanceScore(session: session2, query: query)
                return score1 > score2
            }
        case .timestamp:
            results.sort { $0.startTime > $1.startTime }
        case .duration:
            results.sort { $0.duration > $1.duration }
        case .statusCode:
            results.sort { ($0.statusCode ?? 0) < ($1.statusCode ?? 0) }
        }
        
        return results
    }
    
    private func matchesSession(session: HTTPSession, query: SearchQuery) throws -> Bool {
        // テキスト検索
        if !query.text.isEmpty {
            let textMatches = try matchesText(session: session, text: query.text)
            if !textMatches {
                return false
            }
        }
        
        // フィルター条件
        if let filters = query.filters {
            for filter in filters {
                if !filter.matches(session: session) {
                    return false
                }
            }
        }
        
        // 日付範囲
        if let dateRange = query.dateRange {
            if session.startTime < dateRange.start || session.startTime > dateRange.end {
                return false
            }
        }
        
        return true
    }
    
    private func matchesText(session: HTTPSession, text: String) throws -> Bool {
        let searchOptions: NSString.CompareOptions = configuration.caseSensitive ? [] : [.caseInsensitive]
        
        // 正規表現検索
        if configuration.useRegex {
            let regexOptions: NSRegularExpression.Options = configuration.caseSensitive ? [] : [.caseInsensitive]
            let regex = try NSRegularExpression(pattern: text, options: regexOptions)
            
            for field in configuration.searchFields {
                let fieldText = extractFieldText(from: session, field: field)
                let range = NSRange(location: 0, length: fieldText.count)
                if regex.firstMatch(in: fieldText, options: [], range: range) != nil {
                    return true
                }
            }
            return false
        }
        
        // 通常のテキスト検索
        for field in configuration.searchFields {
            let fieldText = extractFieldText(from: session, field: field)
            if fieldText.range(of: text, options: searchOptions) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func extractFieldText(from session: HTTPSession, field: SearchField) -> String {
        switch field {
        case .url:
            return session.request.url
        case .method:
            return session.request.method.rawValue
        case .statusCode:
            return session.response?.statusCode.description ?? ""
        case .requestHeaders:
            return session.request.headers.map { "\($0.key): \($0.value)" }.joined(separator: " ")
        case .responseHeaders:
            return session.response?.headers.map { "\($0.key): \($0.value)" }.joined(separator: " ") ?? ""
        case .requestBody:
            return session.request.bodyAsString() ?? ""
        case .responseBody:
            return session.response?.bodyAsString() ?? ""
        case .metadata:
            return session.metadata.map { "\($0.key): \($0.value)" }.joined(separator: " ")
        case .host:
            if let url = URL(string: session.request.url) {
                return url.host ?? ""
            }
            return ""
        case .path:
            if let url = URL(string: session.request.url) {
                return url.path
            }
            return ""
        case .queryParameters:
            return session.request.queryParameters().map { "\($0.key): \($0.value)" }.joined(separator: " ")
        }
    }
    
    private func calculateRelevanceScore(session: HTTPSession, query: SearchQuery) -> Double {
        guard !query.text.isEmpty else { return 0.0 }
        
        var score = 0.0
        let searchOptions: NSString.CompareOptions = configuration.caseSensitive ? [] : [.caseInsensitive]
        
        // URLでのマッチは高得点
        if session.request.url.range(of: query.text, options: searchOptions) != nil {
            score += 10.0
        }
        
        // ホスト名でのマッチ
        if let url = URL(string: session.request.url),
           let host = url.host,
           host.range(of: query.text, options: searchOptions) != nil {
            score += 8.0
        }
        
        // パスでのマッチ
        if let url = URL(string: session.request.url),
           url.path.range(of: query.text, options: searchOptions) != nil {
            score += 6.0
        }
        
        // ヘッダーでのマッチ
        for (key, value) in session.request.headers {
            if key.range(of: query.text, options: searchOptions) != nil ||
               value.range(of: query.text, options: searchOptions) != nil {
                score += 3.0
            }
        }
        
        // レスポンスヘッダーでのマッチ
        if let responseHeaders = session.response?.headers {
            for (key, value) in responseHeaders {
                if key.range(of: query.text, options: searchOptions) != nil ||
                   value.range(of: query.text, options: searchOptions) != nil {
                    score += 2.0
                }
            }
        }
        
        // ボディでのマッチ（低得点）
        if let body = session.request.bodyAsString(),
           body.range(of: query.text, options: searchOptions) != nil {
            score += 1.0
        }
        
        if let responseBody = session.response?.bodyAsString(),
           responseBody.range(of: query.text, options: searchOptions) != nil {
            score += 1.0
        }
        
        return score
    }
    
    private func generateHighlights(for sessions: [HTTPSession], query: SearchQuery) -> [UUID: [SearchHighlight]] {
        guard !query.text.isEmpty else { return [:] }
        
        var highlights: [UUID: [SearchHighlight]] = [:]
        let searchOptions: NSString.CompareOptions = configuration.caseSensitive ? [] : [.caseInsensitive]
        
        for session in sessions {
            var sessionHighlights: [SearchHighlight] = []
            
            for field in configuration.searchFields {
                let fieldText = extractFieldText(from: session, field: field)
                let ranges = findAllRanges(of: query.text, in: fieldText, options: searchOptions)
                
                for range in ranges {
                    let highlight = SearchHighlight(
                        field: field,
                        range: range,
                        matchedText: String(fieldText[Range(range, in: fieldText)!])
                    )
                    sessionHighlights.append(highlight)
                }
            }
            
            if !sessionHighlights.isEmpty {
                highlights[session.id] = sessionHighlights
            }
        }
        
        return highlights
    }
    
    private func findAllRanges(of searchText: String, in text: String, options: NSString.CompareOptions) -> [NSRange] {
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: text.count)
        
        while searchRange.location < text.count {
            let foundRange = (text as NSString).range(of: searchText, options: options, range: searchRange)
            
            if foundRange.location == NSNotFound {
                break
            }
            
            ranges.append(foundRange)
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = text.count - searchRange.location
        }
        
        return ranges
    }
}

// MARK: - SearchQuery

/// 検索クエリ
public struct SearchQuery {
    /// 検索テキスト
    public let text: String
    /// フィルター条件
    public let filters: [FilterCriteriaProtocol]?
    /// 日付範囲
    public let dateRange: DateRange?
    /// ソート方法
    public let sortBy: SortOption
    /// 昇順/降順
    public let ascending: Bool
    
    public init(
        text: String = "",
        filters: [FilterCriteriaProtocol]? = nil,
        dateRange: DateRange? = nil,
        sortBy: SortOption = .relevance,
        ascending: Bool = false
    ) {
        self.text = text
        self.filters = filters
        self.dateRange = dateRange
        self.sortBy = sortBy
        self.ascending = ascending
    }
    
    /// ソートオプション
    public enum SortOption {
        case relevance  // 関連度
        case timestamp  // タイムスタンプ
        case duration   // 期間
        case statusCode // ステータスコード
    }
}

/// 日付範囲
public struct DateRange {
    public let start: Date
    public let end: Date
    
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
    
    /// 今日
    public static var today: DateRange {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return DateRange(start: start, end: end)
    }
    
    /// 昨日
    public static var yesterday: DateRange {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -1, to: today)!
        let end = today
        return DateRange(start: start, end: end)
    }
    
    /// 過去7日間
    public static var lastWeek: DateRange {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        return DateRange(start: start, end: end)
    }
    
    /// 過去30日間
    public static var lastMonth: DateRange {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -30, to: end)!
        return DateRange(start: start, end: end)
    }
}

// MARK: - Convenience Extensions

public extension SessionSearchService {
    
    /// 簡易検索
    /// - Parameters:
    ///   - text: 検索テキスト
    ///   - sessions: 検索対象のセッション
    ///   - completion: 完了コールバック
    func simpleSearch(text: String, in sessions: [HTTPSession], completion: @escaping (Result<[HTTPSession], Error>) -> Void) {
        let query = SearchQuery(text: text)
        search(query: query, in: sessions) { result in
            switch result {
            case .success(let searchResult):
                completion(.success(searchResult.sessions))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// ホスト検索
    /// - Parameters:
    ///   - host: ホスト名
    ///   - sessions: 検索対象のセッション
    ///   - completion: 完了コールバック
    func searchByHost(_ host: String, in sessions: [HTTPSession], completion: @escaping (Result<SearchResult, Error>) -> Void) {
        let config = SearchConfiguration(searchFields: [.host, .url])
        let searchService = SessionSearchService(configuration: config)
        let query = SearchQuery(text: host)
        searchService.search(query: query, in: sessions, completion: completion)
    }
    
    /// ステータスコード検索
    /// - Parameters:
    ///   - statusCode: ステータスコード
    ///   - sessions: 検索対象のセッション
    ///   - completion: 完了コールバック
    func searchByStatusCode(_ statusCode: Int, in sessions: [HTTPSession], completion: @escaping (Result<SearchResult, Error>) -> Void) {
        let filter = FilterCriteria().statusCode(statusCode)
        let query = SearchQuery(filters: [filter])
        search(query: query, in: sessions, completion: completion)
    }
    
    /// 正規表現検索
    /// - Parameters:
    ///   - pattern: 正規表現パターン
    ///   - sessions: 検索対象のセッション
    ///   - completion: 完了コールバック
    func regexSearch(pattern: String, in sessions: [HTTPSession], completion: @escaping (Result<SearchResult, Error>) -> Void) {
        let config = SearchConfiguration(useRegex: true)
        let searchService = SessionSearchService(configuration: config)
        let query = SearchQuery(text: pattern)
        searchService.search(query: query, in: sessions, completion: completion)
    }
}