import Foundation

/// フィルタリングエンジンのプロトコル
public protocol FilterEngineProtocol {
    /// セッションリストをフィルタリングする
    /// - Parameters:
    ///   - sessions: フィルタリング対象のセッション配列
    ///   - criteria: フィルタリング条件
    /// - Returns: フィルタリング済みのセッション配列
    func filter(sessions: [HTTPSession], using criteria: FilterCriteriaProtocol) -> [HTTPSession]
    
    /// 複数の条件でフィルタリングする
    /// - Parameters:
    ///   - sessions: フィルタリング対象のセッション配列
    ///   - criteriaList: フィルタリング条件の配列
    ///   - operator: 条件間の論理演算子
    /// - Returns: フィルタリング済みのセッション配列
    func filter(sessions: [HTTPSession], using criteriaList: [FilterCriteriaProtocol], operator: FilterEngine.CriteriaOperator) -> [HTTPSession]
}

/// ネットワークセッションをフィルタリングするメインエンジン
/// 複数の条件を組み合わせた複雑なフィルタリングロジックを提供
public class FilterEngine: FilterEngineProtocol {
    
    /// 複数の条件間での論理演算子
    public enum CriteriaOperator {
        case and  // すべての条件を満たす
        case or   // いずれかの条件を満たす
    }
    
    /// フィルタリングのパフォーマンス統計
    public struct FilteringStats {
        public let totalSessions: Int
        public let filteredSessions: Int
        public let processingTime: TimeInterval
        public let filteringRatio: Double
        
        public init(totalSessions: Int, filteredSessions: Int, processingTime: TimeInterval) {
            self.totalSessions = totalSessions
            self.filteredSessions = filteredSessions
            self.processingTime = processingTime
            self.filteringRatio = totalSessions > 0 ? Double(filteredSessions) / Double(totalSessions) : 0.0
        }
    }
    
    /// 現在適用されているフィルター条件
    public private(set) var activeFilter: FilterCriteriaProtocol?
    
    /// 最後のフィルタリング統計
    public private(set) var lastFilteringStats: FilteringStats?
    
    /// パフォーマンス追跡を有効にするかどうか
    public var isPerformanceTrackingEnabled: Bool = false
    
    /// 初期化
    public init() {}
    
    // MARK: - FilterEngineProtocol Implementation
    
    public func filter(sessions: [HTTPSession], using criteria: FilterCriteriaProtocol) -> [HTTPSession] {
        let startTime = Date()
        
        activeFilter = criteria
        
        let filteredSessions = sessions.filter { session in
            criteria.matches(session: session)
        }
        
        if isPerformanceTrackingEnabled {
            let processingTime = Date().timeIntervalSince(startTime)
            lastFilteringStats = FilteringStats(
                totalSessions: sessions.count,
                filteredSessions: filteredSessions.count,
                processingTime: processingTime
            )
        }
        
        return filteredSessions
    }
    
    public func filter(sessions: [HTTPSession], using criteriaList: [FilterCriteriaProtocol], operator: CriteriaOperator) -> [HTTPSession] {
        guard !criteriaList.isEmpty else { return sessions }
        
        let startTime = Date()
        
        let filteredSessions = sessions.filter { session in
            switch `operator` {
            case .and:
                return criteriaList.allSatisfy { criteria in
                    criteria.matches(session: session)
                }
            case .or:
                return criteriaList.contains { criteria in
                    criteria.matches(session: session)
                }
            }
        }
        
        if isPerformanceTrackingEnabled {
            let processingTime = Date().timeIntervalSince(startTime)
            lastFilteringStats = FilteringStats(
                totalSessions: sessions.count,
                filteredSessions: filteredSessions.count,
                processingTime: processingTime
            )
        }
        
        return filteredSessions
    }
    
    // MARK: - Advanced Filtering Methods
    
    /// セッションを複数のグループに分類する
    /// - Parameters:
    ///   - sessions: 分類対象のセッション配列
    ///   - groupCriteria: グループ分けの条件辞書（キー: グループ名、値: フィルター条件）
    /// - Returns: グループ名をキーとしたセッション配列の辞書
    public func categorize(sessions: [HTTPSession], using groupCriteria: [String: FilterCriteriaProtocol]) -> [String: [HTTPSession]] {
        var result: [String: [HTTPSession]] = [:]
        
        for (groupName, criteria) in groupCriteria {
            result[groupName] = filter(sessions: sessions, using: criteria)
        }
        
        return result
    }
    
    /// セッションを時系列順でソートしながらフィルタリング
    /// - Parameters:
    ///   - sessions: フィルタリング対象のセッション配列
    ///   - criteria: フィルタリング条件
    ///   - ascending: 昇順ソートかどうか（デフォルトはtrue）
    /// - Returns: フィルタリング済みかつソート済みのセッション配列
    public func filterAndSort(sessions: [HTTPSession], using criteria: FilterCriteriaProtocol, ascending: Bool = true) -> [HTTPSession] {
        let filteredSessions = filter(sessions: sessions, using: criteria)
        
        return filteredSessions.sorted { session1, session2 in
            if ascending {
                return session1.startTime < session2.startTime
            } else {
                return session1.startTime > session2.startTime
            }
        }
    }
    
    /// ページネーション付きフィルタリング
    /// - Parameters:
    ///   - sessions: フィルタリング対象のセッション配列
    ///   - criteria: フィルタリング条件
    ///   - page: ページ番号（0から開始）
    ///   - pageSize: 1ページあたりのセッション数
    /// - Returns: フィルタリング済みの指定ページのセッション配列
    public func filterWithPagination(sessions: [HTTPSession], using criteria: FilterCriteriaProtocol, page: Int, pageSize: Int) -> [HTTPSession] {
        let filteredSessions = filter(sessions: sessions, using: criteria)
        
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, filteredSessions.count)
        
        guard startIndex < filteredSessions.count else { return [] }
        
        return Array(filteredSessions[startIndex..<endIndex])
    }
    
    /// フィルタリング結果の統計情報を取得
    /// - Parameters:
    ///   - sessions: 対象のセッション配列
    ///   - criteria: フィルタリング条件
    /// - Returns: フィルタリング統計情報
    public func getFilteringStatistics(sessions: [HTTPSession], using criteria: FilterCriteriaProtocol) -> FilteringStats {
        let startTime = Date()
        let filteredSessions = filter(sessions: sessions, using: criteria)
        let processingTime = Date().timeIntervalSince(startTime)
        
        return FilteringStats(
            totalSessions: sessions.count,
            filteredSessions: filteredSessions.count,
            processingTime: processingTime
        )
    }
    
    // MARK: - Filter Management
    
    /// アクティブなフィルターをクリア
    public func clearActiveFilter() {
        activeFilter = nil
    }
    
    /// フィルタリング統計をリセット
    public func resetStatistics() {
        lastFilteringStats = nil
    }
    
    // MARK: - Utility Methods
    
    /// セッション配列の要約統計を生成
    /// - Parameter sessions: 対象のセッション配列
    /// - Returns: 統計情報辞書
    public func generateSummaryStatistics(for sessions: [HTTPSession]) -> [String: Any] {
        guard !sessions.isEmpty else {
            return ["total": 0]
        }
        
        let totalSessions = sessions.count
        let completedSessions = sessions.filter { $0.isCompleted }.count
        let failedSessions = sessions.filter { $0.isFailed }.count
        let cancelledSessions = sessions.filter { $0.isCancelled }.count
        
        let averageDuration = sessions.compactMap { $0.endTime?.timeIntervalSince($0.startTime) }.reduce(0, +) / Double(sessions.count)
        
        let methodCounts = Dictionary(grouping: sessions, by: { $0.httpMethod })
            .mapValues { $0.count }
        
        let statusCodeCounts = Dictionary(grouping: sessions.compactMap { $0.statusCode }, by: { $0 })
            .mapValues { $0.count }
        
        let hostCounts = Dictionary(grouping: sessions.compactMap { $0.host }, by: { $0 })
            .mapValues { $0.count }
        
        return [
            "total": totalSessions,
            "completed": completedSessions,
            "failed": failedSessions,
            "cancelled": cancelledSessions,
            "averageDuration": averageDuration,
            "methodCounts": methodCounts,
            "statusCodeCounts": statusCodeCounts,
            "hostCounts": hostCounts
        ]
    }
}

// MARK: - Convenience Extensions

public extension FilterEngine {
    
    /// 成功レスポンスのみをフィルタリング
    /// - Parameter sessions: 対象のセッション配列
    /// - Returns: 成功レスポンスのセッション配列
    func filterSuccessOnly(sessions: [HTTPSession]) -> [HTTPSession] {
        return filter(sessions: sessions, using: FilterCriteria.successOnly())
    }
    
    /// エラーレスポンスのみをフィルタリング
    /// - Parameter sessions: 対象のセッション配列
    /// - Returns: エラーレスポンスのセッション配列
    func filterErrorsOnly(sessions: [HTTPSession]) -> [HTTPSession] {
        return filter(sessions: sessions, using: FilterCriteria.errorsOnly())
    }
    
    /// 特定ホストのセッションのみをフィルタリング
    /// - Parameters:
    ///   - sessions: 対象のセッション配列
    ///   - host: ホスト名
    /// - Returns: 指定ホストのセッション配列
    func filterByHost(sessions: [HTTPSession], host: String) -> [HTTPSession] {
        return filter(sessions: sessions, using: FilterCriteria.host(host))
    }
    
    /// 遅いリクエストのみをフィルタリング
    /// - Parameters:
    ///   - sessions: 対象のセッション配列
    ///   - threshold: 閾値（秒、デフォルトは2.0秒）
    /// - Returns: 遅いリクエストのセッション配列
    func filterSlowRequests(sessions: [HTTPSession], threshold: TimeInterval = 2.0) -> [HTTPSession] {
        return filter(sessions: sessions, using: FilterCriteria.slowRequests(threshold: threshold))
    }
}