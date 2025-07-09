# NetworkMonitor セキュリティガイド

## 概要

NetworkMonitorライブラリは、ネットワークトラフィックの監視と分析を行うため、機密情報を扱う可能性があります。このガイドでは、セキュリティリスクと安全な使用方法について説明します。

## 🔒 セキュリティリスクの分類

### 高リスク
- **機密データの漏洩**: HTTPSトラフィックの復号化により、パスワードやAPIキーが露出する可能性
- **認証情報の露出**: Authorizationヘッダーやセッションクッキーが保存される可能性
- **個人情報の取得**: ユーザーの行動パターンや個人データが記録される可能性

### 中リスク
- **ディスク容量の消費**: 大量のネットワークデータが保存されることによる容量不足
- **パフォーマンスへの影響**: 監視処理がアプリケーションのパフォーマンスに与える影響
- **デバッグ情報の残存**: 本番環境でのデバッグ情報の意図しない露出

### 低リスク
- **ログファイルの可視性**: 開発者以外へのログファイル露出
- **メタデータの蓄積**: 時系列データからの行動パターン推測

## 🛡️ セキュリティ対策

### 1. 開発環境での使用に限定

```swift
#if DEBUG
let monitor = NetworkMonitor.shared
monitor.start()
#endif
```

**重要**: 本番環境では絶対に使用しないでください。

### 2. データストレージの暗号化

```swift
// 機密データを含むセッションの保存前に暗号化
let storageConfig = FileSessionStorage.StorageConfiguration(
    fileFormat: .json,
    compressionEnabled: true, // データ圧縮を有効化
    retentionPeriod: 24 * 60 * 60 // 24時間で自動削除
)
```

### 3. 機密情報のフィルタリング

```swift
// 機密情報を含むヘッダーをフィルタリング
let safeSessionFilter = FilterCriteria()
    .metadata(key: "filtered_headers", value: .bool(true))

// Authorizationヘッダーを除外する例
func sanitizeSession(_ session: HTTPSession) -> HTTPSession {
    var sanitizedHeaders = session.request.headers
    sanitizedHeaders.removeValue(forKey: "Authorization")
    sanitizedHeaders.removeValue(forKey: "Cookie")
    
    let sanitizedRequest = HTTPRequest(
        url: session.request.url,
        method: session.request.method,
        headers: sanitizedHeaders,
        body: nil // ボディも除外
    )
    
    return HTTPSession(request: sanitizedRequest, response: session.response)
}
```

### 4. 自動クリーンアップの設定

```swift
let secureStorageConfig = FileSessionStorage.StorageConfiguration(
    maxSessions: 100, // 最大セッション数を制限
    autoCleanup: true, // 自動クリーンアップを有効化
    retentionPeriod: 24 * 60 * 60 // 24時間で自動削除
)
```

### 5. アクセス制御

```swift
// ストレージディレクトリのアクセス権限を制限
let protectedDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    .appendingPathComponent("NetworkMonitor", isDirectory: true)

// ディレクトリの作成時にアクセス権限を設定
try FileManager.default.createDirectory(
    at: protectedDirectory,
    withIntermediateDirectories: true,
    attributes: [.posixPermissions: 0o700] // 所有者のみアクセス可能
)
```

## 🔐 データ保護のベストプラクティス

### 1. 機密データの識別と除外

```swift
// 機密データを含むURLパターンを除外
let sensitiveFilter = FilterCriteria()
    .url(pattern: ".*/auth/.*", isRegex: true, logicalOperator: .and)
    .url(pattern: ".*/password/.*", isRegex: true, logicalOperator: .or)

// 機密データを含むセッションを除外
let safeSessions = sessions.filter { session in
    !sensitiveFilter.matches(session: session)
}
```

### 2. データの匿名化

```swift
func anonymizeSession(_ session: HTTPSession) -> HTTPSession {
    let anonymizedURL = session.request.url.replacingOccurrences(
        of: "user_id=\\d+", 
        with: "user_id=REDACTED",
        options: .regularExpression
    )
    
    let anonymizedRequest = HTTPRequest(
        url: anonymizedURL,
        method: session.request.method,
        headers: [:], // ヘッダーを空にする
        body: nil
    )
    
    return HTTPSession(request: anonymizedRequest, response: session.response)
}
```

### 3. 保存データの暗号化

```swift
import CryptoKit

// データを暗号化して保存
func encryptSessionData(_ data: Data, key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.seal(data, using: key)
    return sealedBox.combined!
}

// データを復号化して読み込み
func decryptSessionData(_ encryptedData: Data, key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
    return try AES.GCM.open(sealedBox, using: key)
}
```

## ⚠️ 特別な注意事項

### 1. HTTPSトラフィックの取り扱い

```swift
// HTTPSトラフィックを監視する場合の警告表示
#if DEBUG
if session.request.url.hasPrefix("https://") {
    print("⚠️  WARNING: Monitoring HTTPS traffic may expose sensitive data")
    print("⚠️  Ensure this is only used in development environment")
}
#endif
```

### 2. 認証情報の保護

```swift
// 認証関連のヘッダーを自動的に除外
let authHeadersToRemove = [
    "Authorization",
    "Cookie",
    "X-API-Key",
    "X-Auth-Token",
    "Bearer",
    "Basic"
]

func removeAuthHeaders(from headers: [String: String]) -> [String: String] {
    return headers.filter { key, _ in
        !authHeadersToRemove.contains { authHeader in
            key.lowercased().contains(authHeader.lowercased())
        }
    }
}
```

### 3. リリースビルドでの自動無効化

```swift
// リリースビルドでは自動的に無効化
public class NetworkMonitor {
    public func start() {
        #if DEBUG
        // 開発環境でのみ動作
        isMonitoring = true
        #else
        print("NetworkMonitor is disabled in release builds")
        #endif
    }
}
```

## 🔍 セキュリティ監査のチェックリスト

### 開発時
- [ ] デバッグビルドでのみ有効化されているか
- [ ] 機密データフィルタリングが適用されているか
- [ ] データ保存期間が適切に設定されているか
- [ ] 暗号化機能が有効化されているか

### デプロイ前
- [ ] 本番ビルドでNetworkMonitorが無効化されているか
- [ ] 保存されたセッションデータが削除されているか
- [ ] デバッグログが残っていないか
- [ ] 機密情報を含むファイルが除外されているか

### 運用時
- [ ] 定期的なデータクリーンアップが実行されているか
- [ ] ストレージ使用量が監視されているか
- [ ] 不正なデータアクセスが検出されていないか

## 📋 コンプライアンス対応

### GDPR対応
- 個人データの収集前にユーザー同意を取得
- データの保存期間を最小限に制限
- データ削除要求に対応可能な仕組みを提供

### セキュリティ標準対応
- OWASP Top 10に準拠したセキュリティ対策
- データ暗号化の実装
- アクセス制御の適切な設定

## 🚨 インシデント対応

### データ漏洩が発生した場合
1. 即座にNetworkMonitorの停止
2. 保存されたデータの削除
3. 影響範囲の調査
4. 関係者への報告

### 対応コード例
```swift
// 緊急時のデータ削除
func emergencyDataCleanup() {
    let storage = FileSessionStorage()
    storage.deleteAll { result in
        switch result {
        case .success():
            print("✅ All session data has been deleted")
        case .failure(let error):
            print("❌ Failed to delete data: \(error)")
        }
    }
}
```

## 🔧 設定例

### 本番環境対応設定
```swift
#if DEBUG
let networkMonitorConfig = NetworkMonitorConfiguration(
    enabled: true,
    storageConfig: FileSessionStorage.StorageConfiguration(
        fileFormat: .json,
        maxSessions: 50,
        autoCleanup: true,
        retentionPeriod: 60 * 60, // 1時間
        compressionEnabled: true
    ),
    sensitiveDataFilter: createSensitiveDataFilter(),
    encryptionEnabled: true
)
#else
let networkMonitorConfig = NetworkMonitorConfiguration(
    enabled: false // 本番環境では完全に無効
)
#endif
```

### 機密データフィルター設定
```swift
func createSensitiveDataFilter() -> FilterCriteria {
    return FilterCriteria()
        .url(pattern: ".*/auth/.*", isRegex: true, logicalOperator: .and)
        .url(pattern: ".*/login/.*", isRegex: true, logicalOperator: .or)
        .url(pattern: ".*/password/.*", isRegex: true, logicalOperator: .or)
        .contentType("application/x-www-form-urlencoded", logicalOperator: .or)
}
```

## 📚 関連リソース

- [Apple Security Programming Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/Security_Overview/)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [iOS Data Protection](https://support.apple.com/guide/security/data-protection-overview-secf013e1131/web)

## 🆘 サポート

セキュリティに関する質問や問題が発生した場合：
1. 本リポジトリのIssueで報告
2. セキュリティ関連の問題は非公開で報告
3. 緊急時は直ちに監視を停止

---

**重要**: このライブラリは開発・デバッグ目的で設計されています。本番環境での使用は推奨されません。セキュリティリスクを十分に理解した上で使用してください。